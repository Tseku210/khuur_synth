import 'reverb.dart';
import 'sound_font.dart';

/// What a synth from `Synth.silent` did, one event for each call it carried
/// out, in the order it carried them out.
///
/// The subclasses are exported by `package:khuur_synth/testing.dart`.
sealed class SynthEvent {
  const SynthEvent();
}

final class Loaded extends SynthEvent {
  const Loaded(this.source);

  final SoundFont source;

  @override
  bool operator ==(Object other) => other is Loaded && other.source == source;

  @override
  int get hashCode => Object.hash(Loaded, source);

  @override
  String toString() => 'Loaded($source)';
}

final class Unloaded extends SynthEvent {
  const Unloaded(this.source);

  final SoundFont source;

  @override
  bool operator ==(Object other) => other is Unloaded && other.source == source;

  @override
  int get hashCode => Object.hash(Unloaded, source);

  @override
  String toString() => 'Unloaded($source)';
}

final class Selected extends SynthEvent {
  const Selected({required this.channel, required this.source, required this.bank, required this.program});

  final int channel;
  final SoundFont source;
  final int bank;
  final int program;

  @override
  bool operator ==(Object other) =>
      other is Selected &&
      other.channel == channel &&
      other.source == source &&
      other.bank == bank &&
      other.program == program;

  @override
  int get hashCode => Object.hash(channel, source, bank, program);

  @override
  String toString() => 'Selected(channel: $channel, source: $source, bank: $bank, program: $program)';
}

final class NoteOn extends SynthEvent {
  const NoteOn({required this.channel, required this.key, required this.velocity, required this.cents});

  final int channel;
  final int key;
  final int velocity;
  final double cents;

  @override
  bool operator ==(Object other) =>
      other is NoteOn &&
      other.channel == channel &&
      other.key == key &&
      other.velocity == velocity &&
      other.cents == cents;

  @override
  int get hashCode => Object.hash(channel, key, velocity, cents);

  @override
  String toString() => 'NoteOn(channel: $channel, key: $key, velocity: $velocity, cents: $cents)';
}

final class NoteOff extends SynthEvent {
  const NoteOff({required this.channel, required this.key});

  final int channel;
  final int key;

  @override
  bool operator ==(Object other) => other is NoteOff && other.channel == channel && other.key == key;

  @override
  int get hashCode => Object.hash(NoteOff, channel, key);

  @override
  String toString() => 'NoteOff(channel: $channel, key: $key)';
}

final class AllNotesOff extends SynthEvent {
  const AllNotesOff();

  @override
  bool operator ==(Object other) => other is AllNotesOff;

  @override
  int get hashCode => (AllNotesOff).hashCode;

  @override
  String toString() => 'AllNotesOff()';
}

final class AllSoundsOff extends SynthEvent {
  const AllSoundsOff();

  @override
  bool operator ==(Object other) => other is AllSoundsOff;

  @override
  int get hashCode => (AllSoundsOff).hashCode;

  @override
  String toString() => 'AllSoundsOff()';
}

final class ReverbChanged extends SynthEvent {
  const ReverbChanged(this.reverb);

  final Reverb? reverb;

  @override
  bool operator ==(Object other) => other is ReverbChanged && other.reverb == reverb;

  @override
  int get hashCode => Object.hash(ReverbChanged, reverb);

  @override
  String toString() => 'ReverbChanged($reverb)';
}

final class ChorusChanged extends SynthEvent {
  const ChorusChanged(this.on);

  final bool on;

  @override
  bool operator ==(Object other) => other is ChorusChanged && other.on == on;

  @override
  int get hashCode => Object.hash(ChorusChanged, on);

  @override
  String toString() => 'ChorusChanged($on)';
}

final class GainChanged extends SynthEvent {
  const GainChanged(this.gain);

  final double gain;

  @override
  bool operator ==(Object other) => other is GainChanged && other.gain == gain;

  @override
  int get hashCode => Object.hash(GainChanged, gain);

  @override
  String toString() => 'GainChanged($gain)';
}

/// The device output opened.
final class Started extends SynthEvent {
  const Started();

  @override
  bool operator ==(Object other) => other is Started;

  @override
  int get hashCode => (Started).hashCode;

  @override
  String toString() => 'Started()';
}

/// The device output closed, after ringing out when [ringOut] is true.
final class Stopped extends SynthEvent {
  const Stopped({required this.ringOut});

  final bool ringOut;

  @override
  bool operator ==(Object other) => other is Stopped && other.ringOut == ringOut;

  @override
  int get hashCode => Object.hash(Stopped, ringOut);

  @override
  String toString() => 'Stopped(ringOut: $ringOut)';
}

final class Rendered extends SynthEvent {
  const Rendered(this.frames);

  final int frames;

  @override
  bool operator ==(Object other) => other is Rendered && other.frames == frames;

  @override
  int get hashCode => Object.hash(Rendered, frames);

  @override
  String toString() => 'Rendered($frames)';
}

final class Closed extends SynthEvent {
  const Closed();

  @override
  bool operator ==(Object other) => other is Closed;

  @override
  int get hashCode => (Closed).hashCode;

  @override
  String toString() => 'Closed()';
}
