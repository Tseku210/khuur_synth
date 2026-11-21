import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../asset_files.dart';
import '../engine.dart';
import '../reverb.dart';
import '../sound_font.dart';
import '../synth_exception.dart';
import 'fluid_bindings.dart';

/// Opened again in each isolate that touches FluidSynth.
final FluidSynthBindings _fluid = FluidSynthBindings(_library());

DynamicLibrary _library() {
  try {
    if (Platform.isIOS) return DynamicLibrary.open('FluidSynth.framework/FluidSynth');
    if (Platform.isAndroid) return DynamicLibrary.open('libfluidsynth.so');
  } on ArgumentError catch (e) {
    throw SynthUnavailable('FluidSynth would not load: ${e.message}');
  }
  throw const SynthUnavailable('khuur_synth plays on iOS and Android only.');
}

/// Every call into FluidSynth. The futures run on a helper isolate, since
/// they can hold the synth's lock for as long as a SoundFont takes to parse,
/// or the audio session takes to change.
final class FluidEngine implements Engine {
  FluidEngine._(this._settings, this._synth);

  /// Throws `SynthUnavailable`.
  ///
  /// With [keepsInput] the iOS driver opens in its low-latency mode, in which
  /// it sets the session to `.playAndRecord` rather than `.playback`, so a
  /// recording keeps its input.
  factory FluidEngine.open({required int channels, bool keepsInput = false}) {
    final settings = _fluid.new_fluid_settings();
    if (settings == nullptr) throw const SynthUnavailable('FluidSynth would not create its settings.');
    final set = using((arena) {
      _fluid.fluid_settings_setint(settings, 'synth.midi-channels'.toNativeUtf8(allocator: arena).cast(), channels);
      if (!keepsInput || !Platform.isIOS) return true;
      return _fluid.fluid_settings_setstr(
            settings,
            'audio.coreaudio.performance-mode'.toNativeUtf8(allocator: arena).cast(),
            'LowLatency'.toNativeUtf8(allocator: arena).cast(),
          ) ==
          0;
    });
    if (!set) {
      _fluid.delete_fluid_settings(settings);
      throw const SynthUnavailable('FluidSynth has no low-latency driver to play beside a recording.');
    }
    final synth = _fluid.new_fluid_synth(settings);
    if (synth == nullptr) {
      _fluid.delete_fluid_settings(settings);
      throw const SynthUnavailable('FluidSynth would not create a synth.');
    }
    return FluidEngine._(settings, synth);
  }

  /// FluidSynth's `fluid_settings_t` is its hashtable type under another
  /// name, so ffigen names it `fluid_hashtable_t`.
  final Pointer<fluid_hashtable_t> _settings;
  final Pointer<fluid_synth_t> _synth;
  var _driver = 0;

  @override
  Future<({int id, List<Preset> presets})> load(SoundFont source) async {
    final path = switch (source) {
      AssetSoundFont(:final key) => await _assetPath(source, key),
      FileSoundFont(:final path) => path,
    };
    final synth = _synth.address;
    final loaded = await Isolate.run(() => _loadOn(synth, path));
    return loaded ?? (throw SoundFontLoadFailed(source, 'FluidSynth could not read $path'));
  }

  static Future<String> _assetPath(SoundFont source, String key) async {
    try {
      return await AssetFiles.shared.pathOf(key);
    } catch (e) {
      throw SoundFontLoadFailed(source, 'The asset would not copy to a file: $e');
    }
  }

  static ({int id, List<Preset> presets})? _loadOn(int address, String path) {
    final synth = Pointer<fluid_synth_t>.fromAddress(address);
    final id = using((arena) => _fluid.fluid_synth_sfload(synth, path.toNativeUtf8(allocator: arena).cast(), 0));
    if (id < 0) return null;
    final font = _fluid.fluid_synth_get_sfont_by_id(synth, id);
    final presets = <Preset>[];
    _fluid.fluid_sfont_iteration_start(font);
    for (var p = _fluid.fluid_sfont_iteration_next(font); p != nullptr; p = _fluid.fluid_sfont_iteration_next(font)) {
      presets.add(
        Preset(
          bank: _fluid.fluid_preset_get_banknum(p),
          program: _fluid.fluid_preset_get_num(p),
          name: _fluid.fluid_preset_get_name(p).cast<Utf8>().toDartString(),
        ),
      );
    }
    return (id: id, presets: presets);
  }

  @override
  Future<void> unload(int id) {
    final synth = _synth.address;
    return Isolate.run(() => _fluid.fluid_synth_sfunload(Pointer.fromAddress(synth), id, 0));
  }

  @override
  Future<void> openAudio() async {
    final settings = _settings.address;
    final synth = _synth.address;
    _driver = await Isolate.run(
      () => _fluid.new_fluid_audio_driver(Pointer.fromAddress(settings), Pointer.fromAddress(synth)).address,
    );
    if (_driver == 0) throw const AudioOutputFailed('FluidSynth would not open the audio output.');
  }

  @override
  Future<void> closeAudio() async {
    final driver = _driver;
    if (driver == 0) return;
    _driver = 0;
    await Isolate.run(() => _fluid.delete_fluid_audio_driver(Pointer.fromAddress(driver)));
  }

  @override
  Future<Float32List> render(int frames) {
    final synth = _synth.address;
    return Isolate.run(() {
      final buffer = calloc<Float>(frames * 2);
      try {
        _fluid.fluid_synth_write_float(Pointer.fromAddress(synth), frames, buffer.cast(), 0, 2, buffer.cast(), 1, 2);
        return Float32List.fromList(buffer.asTypedList(frames * 2));
      } finally {
        calloc.free(buffer);
      }
    });
  }

  @override
  Future<void> close() async {
    await closeAudio();
    final settings = _settings.address;
    final synth = _synth.address;
    await Isolate.run(() {
      _fluid.delete_fluid_synth(Pointer.fromAddress(synth));
      _fluid.delete_fluid_settings(Pointer.fromAddress(settings));
    });
  }

  @override
  void select(int channel, int id, int bank, int program) =>
      _fluid.fluid_synth_program_select(_synth, channel, id, bank, program);

  @override
  void unset(int channel) => _fluid.fluid_synth_unset_program(_synth, channel);

  @override
  void noteOn(int channel, int key, int velocity) => _fluid.fluid_synth_noteon(_synth, channel, key, velocity);

  @override
  void noteOff(int channel, int key) => _fluid.fluid_synth_noteoff(_synth, channel, key);

  @override
  void controlChange(int channel, int controller, int value) =>
      _fluid.fluid_synth_cc(_synth, channel, controller, value);

  @override
  void allNotesOff() => _fluid.fluid_synth_all_notes_off(_synth, -1);

  @override
  void allSoundsOff() => _fluid.fluid_synth_all_sounds_off(_synth, -1);

  /// Each channel tunes in its own slot, bank `channel ~/ 128` and program
  /// `channel % 128`. The first call creates it in equal temperament.
  @override
  void tuneKey(int channel, int key, double cents) => using((arena) {
    final keys = arena<Int>()..value = key;
    final pitch = arena<Double>()..value = key * 100 + cents;
    _fluid.fluid_synth_tune_notes(_synth, channel ~/ 128, channel % 128, 1, keys, pitch, 0);
  });

  @override
  void activateTuning(int channel) =>
      _fluid.fluid_synth_activate_tuning(_synth, channel, channel ~/ 128, channel % 128, 0);

  @override
  void setReverb(Reverb? reverb) {
    _fluid.fluid_synth_reverb_on(_synth, -1, reverb == null ? 0 : 1);
    if (reverb == null) return;
    _fluid
      ..fluid_synth_set_reverb_group_roomsize(_synth, -1, reverb.roomSize)
      ..fluid_synth_set_reverb_group_damp(_synth, -1, reverb.damping)
      ..fluid_synth_set_reverb_group_width(_synth, -1, reverb.width)
      ..fluid_synth_set_reverb_group_level(_synth, -1, reverb.level);
  }

  @override
  void setChorus(bool on) => _fluid.fluid_synth_chorus_on(_synth, -1, on ? 1 : 0);

  @override
  void setGain(double gain) => _fluid.fluid_synth_set_gain(_synth, gain);

  @override
  int get activeVoices => _fluid.fluid_synth_get_active_voice_count(_synth);
}
