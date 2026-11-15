import 'sound_font.dart';

/// A device or file state that stops a synth from doing what was asked.
///
/// A mistake in the arguments is a [RangeError], [ArgumentError] or
/// [StateError] instead.
sealed class SynthException implements Exception {
  /// An exception that says [message].
  const SynthException(this.message);

  /// What went wrong, in words for a log.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// FluidSynth cannot run here: the platform is not iOS or Android, or the
/// library would not load.
final class SynthUnavailable extends SynthException {
  /// FluidSynth cannot run, for the reason [message] gives.
  const SynthUnavailable(super.message);
}

/// A SoundFont that is missing or that FluidSynth cannot read.
final class SoundFontLoadFailed extends SynthException {
  /// [source] would not load, for the reason [message] gives.
  const SoundFontLoadFailed(this.source, super.message);

  /// The SoundFont that would not load.
  final SoundFont source;
}

/// A SoundFont that has no preset at the bank and program asked for.
final class PresetNotFound extends SynthException {
  /// [source] has no preset at [bank] and [program].
  PresetNotFound(this.source, this.bank, this.program) : super('$source has no preset $bank:$program');

  /// The SoundFont that lacks the preset.
  final SoundFont source;

  /// The bank asked for.
  final int bank;

  /// The program asked for.
  final int program;
}

/// The device's audio output would not open.
final class AudioOutputFailed extends SynthException {
  /// The output would not open, for the reason [message] gives.
  const AudioOutputFailed(super.message);
}
