import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'audio_session.dart';
import 'engine.dart';
import 'fluid/fluid_engine.dart';
import 'key_tuning.dart';
import 'reverb.dart';
import 'sound_font.dart';
import 'synth_event.dart';
import 'synth_exception.dart';

/// One FluidSynth synthesizer: its SoundFonts, [channelCount] MIDI channels,
/// reverb, chorus and gain, and while started, its own device output.
///
/// Two synths share nothing but the samples of a file both load, which
/// FluidSynth keeps once per process.
///
/// Calls that wait (`load`, `unload`, `start`, `stop`, `render`, `close`)
/// run one at a time, in the order they were made. A note or setting made
/// while one of them runs waits for it in Dart, so no call blocks the UI
/// isolate on FluidSynth's lock, and every call takes effect in the order it
/// was made.
final class Synth {
  Synth._(this._engine, this._session, this._policy, this._onEvent, this._reverb, this._chorus, this._gain) {
    _engine
      ..setReverb(_reverb)
      ..setChorus(_chorus)
      ..setGain(_gain);
  }

  static const channelCount = 256;

  /// A synth with FluidSynth's own sound: its reverb, its chorus and a gain
  /// of 0.2. Throws [SynthUnavailable] where FluidSynth cannot run, which is
  /// anywhere but iOS and Android.
  static Future<Synth> open({
    Reverb? reverb = const Reverb(),
    bool chorus = true,
    double gain = 0.2,
    AudioSessionPolicy session = AudioSessionPolicy.playback,
  }) async {
    _checkReverb(reverb);
    _checkGain(gain);
    return Synth._(
      FluidEngine.open(channels: channelCount),
      PlatformAudioSession.instance,
      session,
      null,
      reverb,
      chorus,
      gain,
    );
  }

  /// A synth that runs every rule of a real one and makes no sound, for
  /// tests and for places with no FluidSynth.
  ///
  /// [onEvent] hears each call as the synth carries it out. A load reads no
  /// file and finds the presets [presets] gives for the source, by default
  /// every program of bank 0 and program 0 of bank 128. A [presets] that
  /// throws [SoundFontLoadFailed] makes that load fail.
  static Future<Synth> silent({
    void Function(SynthEvent event)? onEvent,
    List<Preset> Function(SoundFont source)? presets,
    Reverb? reverb = const Reverb(),
    bool chorus = true,
    double gain = 0.2,
  }) async =>
      synthOver(NoEngine(presets ?? (_) => _generalMidi), onEvent: onEvent, reverb: reverb, chorus: chorus, gain: gain);

  static final _generalMidi = List<Preset>.unmodifiable([
    for (var program = 0; program < 128; program++) Preset(bank: 0, program: program, name: ''),
    const Preset(bank: 128, program: 0, name: ''),
  ]);

  static const _ringTick = Duration(milliseconds: 50);
  static const _ringQuietTicks = 2;
  static const _ringMaxTicks = 200;

  final Engine _engine;
  final AudioSession _session;
  final AudioSessionPolicy _policy;
  final void Function(SynthEvent event)? _onEvent;
  final _tuning = KeyTuning();
  final _fonts = <int, LoadedSoundFont>{};
  final _jobs = Queue<_Job>();
  var _pumping = false;
  _Audio _audio = const _Stopped();
  StreamSubscription<void>? _resets;
  Future<void>? _closing;
  Reverb? _reverb;
  bool _chorus;
  double _gain;

  /// Loads a SoundFont and reads its presets. Throws [SoundFontLoadFailed].
  ///
  /// The audio may stall while a large file parses, so load before playing.
  Future<LoadedSoundFont> load(SoundFont source) {
    _checkOpen();
    return _op(() async {
      final loaded = await _engine.load(source);
      _emit(Loaded(source));
      return LoadedSoundFont._(this, loaded.id, source, List.unmodifiable(loaded.presets));
    });
  }

  /// Frees a SoundFont. Every channel that played from it goes silent.
  Future<void> unload(LoadedSoundFont font) {
    _checkOpen();
    _checkFont(font);
    font._unloaded = true;
    for (final channel in [
      for (final MapEntry(:key, :value) in _fonts.entries)
        if (value == font) key,
    ]) {
      _fonts.remove(channel);
      _command(() => _engine.unset(channel));
    }
    return _op(() async {
      await _engine.unload(font._id);
      _emit(Unloaded(font.source));
    });
  }

  /// Sets what [channel] plays. Throws [PresetNotFound] when [font] has no
  /// such preset, and the channel then plays nothing.
  void select({required int channel, required LoadedSoundFont font, required int program, int bank = 0}) {
    _checkOpen();
    _checkChannel(channel);
    _checkFont(font);
    RangeError.checkValueInInterval(program, 0, 127, 'program');
    RangeError.checkValueInInterval(bank, 0, 16383, 'bank');
    if (!font.presets.any((p) => p.bank == bank && p.program == program)) {
      _fonts.remove(channel);
      _command(() => _engine.unset(channel));
      throw PresetNotFound(font.source, bank, program);
    }
    _fonts[channel] = font;
    _command(() {
      _engine.select(channel, font._id, bank, program);
      _emit(Selected(channel: channel, source: font.source, bank: bank, program: program));
    });
  }

  /// Strikes [key]. [cents] detunes this note alone, from -1200 to 1200, and
  /// leaves the notes already sounding where they are.
  void noteOn({required int channel, required int key, int velocity = 100, double cents = 0}) {
    _checkOpen();
    _checkChannel(channel);
    _checkKey(key);
    RangeError.checkValueInInterval(velocity, 1, 127, 'velocity');
    _checkReal(cents, -1200, 1200, 'cents');
    _command(() {
      final step = _tuning.prepare(channel, key, cents);
      if (step.retune) _engine.tuneKey(channel, key, cents);
      if (step.activate) _engine.activateTuning(channel);
      _engine.noteOn(channel, key, velocity);
      _emit(NoteOn(channel: channel, key: key, velocity: velocity, cents: cents));
    });
  }

  void noteOff({required int channel, required int key}) {
    _checkOpen();
    _checkChannel(channel);
    _checkKey(key);
    _command(() {
      _engine.noteOff(channel, key);
      _emit(NoteOff(channel: channel, key: key));
    });
  }

  /// Releases every note, which then fades as its release says.
  void allNotesOff() {
    _checkOpen();
    _command(() {
      _engine.allNotesOff();
      _emit(const AllNotesOff());
    });
  }

  /// Silences every note at once.
  void allSoundsOff() {
    _checkOpen();
    _command(() {
      _engine.allSoundsOff();
      _emit(const AllSoundsOff());
    });
  }

  /// The reverb, or null for none.
  Reverb? get reverb => _reverb;

  set reverb(Reverb? value) {
    _checkOpen();
    _checkReverb(value);
    _reverb = value;
    _command(() {
      _engine.setReverb(value);
      _emit(ReverbChanged(value));
    });
  }

  bool get chorus => _chorus;

  set chorus(bool value) {
    _checkOpen();
    _chorus = value;
    _command(() {
      _engine.setChorus(value);
      _emit(ChorusChanged(value));
    });
  }

  /// From 0 to 10. FluidSynth's default is 0.2.
  double get gain => _gain;

  set gain(double value) {
    _checkOpen();
    _checkGain(value);
    _gain = value;
    _command(() {
      _engine.setGain(value);
      _emit(GainChanged(value));
    });
  }

  /// Opens the device output, so notes sound. Throws [AudioOutputFailed].
  ///
  /// On iOS it sets the audio session as the synth's [AudioSessionPolicy]
  /// says, and opens the output again after an interruption ends or the media
  /// services reset. A start while ringing out keeps the output open.
  Future<void> start() {
    _checkOpen();
    switch (_audio) {
      case _Started():
        return Future.value();
      case _Starting(:final opened):
        return opened;
      case final _Ringing ringing:
        ringing.finish();
        _audio = const _Started();
        return Future.value();
      case _Stopped():
        final opened = _op(_open);
        _audio = _Starting(opened);
        return opened;
    }
  }

  Future<void> _open() async {
    if (_closing != null) return;
    try {
      await _openOutput();
    } catch (_) {
      _audio = const _Stopped();
      rethrow;
    }
    _audio = const _Started();
    _resets = _session.resets.listen((_) => _reopen());
    _emit(const Started());
  }

  /// FluidSynth's driver sets the iOS session itself, to `.playback` mixed
  /// with others, so the policy is set again once the driver is open.
  Future<void> _openOutput() async {
    await _session.activate(_policy);
    await _engine.openAudio();
    await _session.activate(_policy);
  }

  void _reopen() {
    unawaited(
      _op(() async {
        if (_audio is! _Started && _audio is! _Ringing) return;
        await _engine.closeAudio();
        await _openOutput();
      }).catchError((Object _) {
        if (_audio case final _Ringing ringing) ringing.finish();
        _audio = const _Stopped();
        _resets?.cancel();
      }),
    );
  }

  /// Closes the device output. With [ringOut] the notes are released first,
  /// and the output closes once the last one has faded, or after 10 s.
  Future<void> stop({bool ringOut = false}) {
    _checkOpen();
    switch (_audio) {
      case _Stopped():
        return Future.value();
      case _Starting(:final opened):
        return opened.then((_) => stop(ringOut: ringOut), onError: (Object _) {});
      case _Started():
        return ringOut ? _ringOut() : _close(ringOut: false);
      case final _Ringing ringing:
        if (ringOut) return ringing.closed;
        final closed = _close(ringOut: false);
        ringing.finish(closed);
        return closed;
    }
  }

  Future<void> _ringOut() {
    _command(_engine.allNotesOff);
    var ticks = 0;
    var quiet = 0;
    late final _Ringing ringing;
    final timer = Timer.periodic(_ringTick, (_) {
      ticks++;
      if (!_pumping) quiet = _engine.activeVoices == 0 ? quiet + 1 : 0;
      if (quiet < _ringQuietTicks && ticks < _ringMaxTicks) return;
      ringing.finish(_close(ringOut: true));
    });
    ringing = _Ringing(timer);
    _audio = ringing;
    return ringing.closed;
  }

  Future<void> _close({required bool ringOut}) {
    _audio = const _Stopped();
    _resets?.cancel();
    _resets = null;
    if (!ringOut) _command(_engine.allSoundsOff);
    return _op(() async {
      await _engine.closeAudio();
      _emit(Stopped(ringOut: ringOut));
    });
  }

  /// Renders [frames] of interleaved stereo at 44.1 kHz without the device,
  /// for checks and bounces. Only while stopped.
  Future<Float32List> render(int frames) {
    _checkOpen();
    RangeError.checkValueInInterval(frames, 1, 44100 * 600, 'frames');
    if (_audio is! _Stopped) throw StateError('A synth renders only while it is stopped.');
    return _op(() async {
      final samples = await _engine.render(frames);
      _emit(Rendered(frames));
      return samples;
    });
  }

  /// Closes the output and frees the synth, after every call made before it.
  /// Any later call throws a [StateError].
  Future<void> close() => _closing ??= _shutDown();

  Future<void> _shutDown() {
    if (_audio case final _Ringing ringing) ringing.finish();
    _audio = const _Stopped();
    _resets?.cancel();
    _resets = null;
    return _op(() async {
      await _engine.close();
      _emit(const Closed());
    });
  }

  Future<T> _op<T>(Future<T> Function() run) {
    final done = Completer<T>();
    _jobs.add(
      _Op(() async {
        try {
          done.complete(await run());
        } catch (e, s) {
          done.completeError(e, s);
        }
      }),
    );
    unawaited(_pump());
    return done.future;
  }

  void _command(void Function() run) {
    if (_pumping) {
      _jobs.add(_Command(run));
    } else {
      run();
    }
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_jobs.isNotEmpty) {
        switch (_jobs.removeFirst()) {
          case _Command(:final run):
            run();
          case _Op(:final run):
            await run();
        }
      }
    } finally {
      _pumping = false;
    }
  }

  void _emit(SynthEvent event) => _onEvent?.call(event);

  void _checkOpen() {
    if (_closing != null) throw StateError('The synth is closed.');
  }

  void _checkFont(LoadedSoundFont font) {
    if (!identical(font._owner, this)) throw ArgumentError.value(font, 'font', 'was loaded by another synth');
    if (font._unloaded) throw ArgumentError.value(font, 'font', 'was unloaded');
  }

  static void _checkChannel(int channel) => RangeError.checkValueInInterval(channel, 0, channelCount - 1, 'channel');

  static void _checkKey(int key) => RangeError.checkValueInInterval(key, 0, 127, 'key');

  static void _checkGain(double gain) {
    _checkReal(gain, 0, 10, 'gain');
  }

  static void _checkReverb(Reverb? reverb) {
    if (reverb == null) return;
    _checkReal(reverb.roomSize, 0, 1, 'roomSize');
    _checkReal(reverb.damping, 0, 1, 'damping');
    _checkReal(reverb.width, 0, 100, 'width');
    _checkReal(reverb.level, 0, 1, 'level');
  }

  static void _checkReal(double value, double min, double max, String name) {
    if (!(value >= min && value <= max)) throw RangeError.value(value, name, 'Must be from $min to $max');
  }
}

/// A synth over [engine], for this package's tests.
Synth synthOver(
  Engine engine, {
  AudioSession session = const NoAudioSession(),
  AudioSessionPolicy policy = AudioSessionPolicy.manual,
  void Function(SynthEvent event)? onEvent,
  Reverb? reverb = const Reverb(),
  bool chorus = true,
  double gain = 0.2,
}) {
  Synth._checkReverb(reverb);
  Synth._checkGain(gain);
  return Synth._(engine, session, policy, onEvent, reverb, chorus, gain);
}

/// A SoundFont as one synth loaded it. It plays only on that synth.
final class LoadedSoundFont {
  LoadedSoundFont._(this._owner, this._id, this.source, this.presets);

  final Synth _owner;
  final int _id;
  final SoundFont source;

  /// Every preset in the file, in the order FluidSynth lists them.
  final List<Preset> presets;

  var _unloaded = false;

  @override
  String toString() => 'LoadedSoundFont($source)';
}

sealed class _Audio {
  const _Audio();
}

final class _Stopped extends _Audio {
  const _Stopped();
}

final class _Starting extends _Audio {
  const _Starting(this.opened);

  final Future<void> opened;
}

final class _Started extends _Audio {
  const _Started();
}

final class _Ringing extends _Audio {
  _Ringing(this._timer);

  final Timer _timer;
  final _closed = Completer<void>();

  /// What the `stop(ringOut: true)` that began the ring answers.
  Future<void> get closed => _closed.future;

  /// Ends the ring, with the close that ends it, if one does.
  void finish([Future<void>? close]) {
    _timer.cancel();
    _closed.complete(close);
  }
}

sealed class _Job {}

final class _Command extends _Job {
  _Command(this.run);

  final void Function() run;
}

final class _Op extends _Job {
  _Op(this.run);

  final Future<void> Function() run;
}
