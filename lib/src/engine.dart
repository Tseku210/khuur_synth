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

  /// Frees the SoundFont loaded as [id].
  Future<void> unload(int id);

  /// Throws `AudioOutputFailed`.
  Future<void> openAudio();

  /// Closes the device output.
  Future<void> closeAudio();

  /// Interleaved stereo, `frames * 2` samples.
  Future<Float32List> render(int frames);

  /// Closes the audio output if it is open and frees the synth.
  Future<void> close();

  /// Sets [channel] to play [program] of [bank] in the SoundFont [id].
  void select(int channel, int id, int bank, int program);

  /// Sets [channel] to play nothing.
  void unset(int channel);

  /// Strikes [key] on [channel].
  void noteOn(int channel, int key, int velocity);

  /// Releases [key] on [channel].
  void noteOff(int channel, int key);

  /// Sets [controller] of [channel] to [value].
  void controlChange(int channel, int controller, int value);

  /// Releases every note.
  void allNotesOff();

  /// Silences every note at once.
  void allSoundsOff();

  /// Tunes [key] on [channel] [cents] away from equal temperament.
  void tuneKey(int channel, int key, double cents);

  /// Makes [channel] play through its tuning.
  void activateTuning(int channel);

  /// Sets the reverb, or turns it off for null.
  void setReverb(Reverb? reverb);

  /// Turns the chorus on or off.
  void setChorus(bool on);

  /// Sets the gain.
  void setGain(double gain);

  /// How many voices sound now, counting those still fading.
  int get activeVoices;
}

/// An engine that makes no sound, behind `Synth.silent`.
final class NoEngine implements Engine {
  /// An engine whose loads find the presets [_presets] gives.
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
  void controlChange(int channel, int controller, int value) {}

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
