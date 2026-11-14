import 'dart:typed_data';

import 'reverb.dart';
import 'sound_font.dart';

/// One synth's native side, in Dart values.
///
/// `Synth` validates every argument and orders every call, so an engine
/// trusts what it is given. The futures run off the calling isolate where the
/// engine is FluidSynth; the rest are quick and synchronous.
abstract interface class Engine {
  /// Throws `SoundFontLoadFailed`.
  Future<({int id, List<Preset> presets})> load(SoundFont source);

  Future<void> unload(int id);

  /// Throws `AudioOutputFailed`.
  Future<void> openAudio();

  Future<void> closeAudio();

  /// Interleaved stereo, `frames * 2` samples.
  Future<Float32List> render(int frames);

  /// Closes the audio output if it is open and frees the synth.
  Future<void> close();

  void select(int channel, int id, int bank, int program);

  void unset(int channel);

  void noteOn(int channel, int key, int velocity);

  void noteOff(int channel, int key);

  void allNotesOff();

  void allSoundsOff();

  void tuneKey(int channel, int key, double cents);

  void activateTuning(int channel);

  void setReverb(Reverb? reverb);

  void setChorus(bool on);

  void setGain(double gain);

  int get activeVoices;
}

/// An engine that makes no sound, behind `Synth.silent`.
final class NoEngine implements Engine {
  NoEngine(this._presets);

  final List<Preset> Function(SoundFont source) _presets;
  var _nextId = 1;

  @override
  Future<({int id, List<Preset> presets})> load(SoundFont source) async => (id: _nextId++, presets: _presets(source));

  @override
  Future<void> unload(int id) async {}

  @override
  Future<void> openAudio() async {}

  @override
  Future<void> closeAudio() async {}

  @override
  Future<Float32List> render(int frames) async => Float32List(frames * 2);

  @override
  Future<void> close() async {}

  @override
  void select(int channel, int id, int bank, int program) {}

  @override
  void unset(int channel) {}

  @override
  void noteOn(int channel, int key, int velocity) {}

  @override
  void noteOff(int channel, int key) {}

  @override
  void allNotesOff() {}

  @override
  void allSoundsOff() {}

  @override
  void tuneKey(int channel, int key, double cents) {}

  @override
  void activateTuning(int channel) {}

  @override
  void setReverb(Reverb? reverb) {}

  @override
  void setChorus(bool on) {}

  @override
  void setGain(double gain) {}

  @override
  int get activeVoices => 0;
}
