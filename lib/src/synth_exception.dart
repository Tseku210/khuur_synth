import 'sound_font.dart';

/// A device or file state that stops a synth from doing what was asked.
///
/// A mistake in the arguments is a [RangeError], [ArgumentError] or
/// [StateError] instead.
sealed class SynthException implements Exception {
  const SynthException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// FluidSynth cannot run here: the platform is not iOS or Android, or the
/// library would not load.
final class SynthUnavailable extends SynthException {
  const SynthUnavailable(super.message);
}

/// A SoundFont that is missing or that FluidSynth cannot read.
final class SoundFontLoadFailed extends SynthException {
  const SoundFontLoadFailed(this.source, super.message);

  final SoundFont source;
}

/// A SoundFont that has no preset at the bank and program asked for.
final class PresetNotFound extends SynthException {
  PresetNotFound(this.source, this.bank, this.program) : super('$source has no preset $bank:$program');

  final SoundFont source;
  final int bank;
  final int program;
}

/// The device's audio output would not open.
final class AudioOutputFailed extends SynthException {
  const AudioOutputFailed(super.message);
}
