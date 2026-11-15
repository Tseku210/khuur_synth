import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:khuur_synth/khuur_synth.dart';
import 'package:khuur_synth/src/audio_session.dart';
import 'package:khuur_synth/src/engine.dart';

/// Writes each call to [log] as a short line, so a test reads the order.
final class FakeEngine implements Engine {
  FakeEngine(this.log);

  final List<String> log;

  /// While set, a load waits for it.
  Completer<void>? loadGate;

  /// What the next opens throw, one each, in order. An open with none left opens.
  final openErrors = Queue<Object>();
  var voices = 0;
  var _nextId = 1;

  @override
  Future<({int id, List<Preset> presets})> load(SoundFont source) async {
    log.add('load $source');
    await loadGate?.future;
    return (id: _nextId++, presets: const [Preset(bank: 0, program: 0, name: 'Piano')]);
  }

  @override
  Future<void> unload(int id) async => log.add('unload $id');

  @override
  Future<void> openAudio() async {
    log.add('openAudio');
    if (openErrors.isNotEmpty) throw openErrors.removeFirst();
  }

  @override
  Future<void> closeAudio() async => log.add('closeAudio');

  @override
  Future<Float32List> render(int frames) async {
    log.add('render $frames');
    return Float32List(frames * 2);
  }

  @override
  Future<void> close() async => log.add('close');

  @override
  void select(int channel, int id, int bank, int program) => log.add('select $channel $id $bank:$program');

  @override
  void unset(int channel) => log.add('unset $channel');

  @override
  void noteOn(int channel, int key, int velocity) => log.add('noteOn $channel $key $velocity');

  @override
  void noteOff(int channel, int key) => log.add('noteOff $channel $key');

  @override
  void allNotesOff() => log.add('allNotesOff');

  @override
  void allSoundsOff() => log.add('allSoundsOff');

  @override
  void tuneKey(int channel, int key, double cents) => log.add('tuneKey $channel $key $cents');

  @override
  void activateTuning(int channel) => log.add('activateTuning $channel');

  @override
  void setReverb(Reverb? reverb) => log.add('setReverb $reverb');

  @override
  void setChorus(bool on) => log.add('setChorus $on');

  @override
  void setGain(double gain) => log.add('setGain $gain');

  @override
  int get activeVoices => voices;
}

final class FakeSession implements AudioSession {
  FakeSession(this.log);

  final List<String> log;
  final _resets = StreamController<void>.broadcast(sync: true);

  void reset() => _resets.add(null);

  @override
  Future<void> activate(AudioSessionPolicy policy) async => log.add('activate ${policy.name}');

  @override
  Stream<void> get resets => _resets.stream;
}
