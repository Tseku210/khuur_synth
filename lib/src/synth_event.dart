import 'reverb.dart';
import 'sound_font.dart';

/// What a synth from `Synth.silent` did, one event for each call it carried
/// out, in the order it carried them out.
///
/// A call that changed nothing, such as a `start` while started, and a call
/// that threw report nothing. The notes a `stop` releases or cuts are not
/// reported apart from its [Stopped].
///
/// The subclasses are exported by `package:khuur_synth/testing.dart`.
sealed class SynthEvent {
  /// Lets the subclasses be constant.
  const SynthEvent();
}

/// A SoundFont loaded.
final class Loaded extends SynthEvent {
  /// [source] loaded.
  const Loaded(this.source);

  /// The SoundFont that loaded.
  final SoundFont source;

  @override
  bool operator ==(Object other) => other is Loaded && other.source == source;

  @override
  int get hashCode => Object.hash(Loaded, source);

  @override
  String toString() => 'Loaded($source)';
}

/// A SoundFont was freed.
final class Unloaded extends SynthEvent {
  /// [source] was freed.
  const Unloaded(this.source);

  /// The SoundFont that was freed.
  final SoundFont source;

  @override
  bool operator ==(Object other) => other is Unloaded && other.source == source;

  @override
  int get hashCode => Object.hash(Unloaded, source);

  @override
  String toString() => 'Unloaded($source)';
}

/// A channel was set to play a preset.
final class Selected extends SynthEvent {
  /// [channel] plays [program] of [bank] in [source].
  const Selected({required this.channel, required this.source, required this.bank, required this.program});

  /// The channel, from 0 to 255.
  final int channel;

  /// The SoundFont the preset is in.
  final SoundFont source;

  /// The preset's bank, from 0 to 16383.
  final int bank;

  /// The preset's program, from 0 to 127.
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

/// A note was struck.
final class NoteOn extends SynthEvent {
  /// [key] was struck on [channel] at [velocity], detuned by [cents].
  const NoteOn({required this.channel, required this.key, required this.velocity, required this.cents});

  /// The channel, from 0 to 255.
  final int channel;

  /// The MIDI key, from 0 to 127.
  final int key;

  /// From 1 to 127.
  final int velocity;

  /// How far the note was detuned, from -1200 to 1200.
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

/// A note was released.
final class NoteOff extends SynthEvent {
  /// [key] was released on [channel].
  const NoteOff({required this.channel, required this.key});

  /// The channel, from 0 to 255.
  final int channel;

  /// The MIDI key, from 0 to 127.
  final int key;

  @override
  bool operator ==(Object other) => other is NoteOff && other.channel == channel && other.key == key;

  @override
  int get hashCode => Object.hash(NoteOff, channel, key);

  @override
  String toString() => 'NoteOff(channel: $channel, key: $key)';
}

/// A channel's MIDI controller was set.
final class ControlChanged extends SynthEvent {
  /// [controller] of [channel] was set to [value].
  const ControlChanged({required this.channel, required this.controller, required this.value});

  /// The channel, from 0 to 255.
  final int channel;

  /// The MIDI controller, from 0 to 127.
  final int controller;

  /// From 0 to 127.
  final int value;

  @override
  bool operator ==(Object other) =>
      other is ControlChanged && other.channel == channel && other.controller == controller && other.value == value;

  @override
  int get hashCode => Object.hash(ControlChanged, channel, controller, value);

  @override
  String toString() => 'ControlChanged(channel: $channel, controller: $controller, value: $value)';
}

/// Every note was released.
final class AllNotesOff extends SynthEvent {
  /// Every note was released.
  const AllNotesOff();

  @override
  bool operator ==(Object other) => other is AllNotesOff;

  @override
  int get hashCode => (AllNotesOff).hashCode;

  @override
  String toString() => 'AllNotesOff()';
}

/// Every note was silenced at once.
final class AllSoundsOff extends SynthEvent {
  /// Every note was silenced at once.
  const AllSoundsOff();

  @override
  bool operator ==(Object other) => other is AllSoundsOff;

  @override
  int get hashCode => (AllSoundsOff).hashCode;

  @override
  String toString() => 'AllSoundsOff()';
}

/// The reverb was set.
final class ReverbChanged extends SynthEvent {
  /// The reverb was set to [reverb].
  const ReverbChanged(this.reverb);

  /// The new reverb, or null for none.
  final Reverb? reverb;

  @override
  bool operator ==(Object other) => other is ReverbChanged && other.reverb == reverb;

  @override
  int get hashCode => Object.hash(ReverbChanged, reverb);

  @override
  String toString() => 'ReverbChanged($reverb)';
}

/// The chorus was turned on or off.
final class ChorusChanged extends SynthEvent {
  /// The chorus was turned on when [on] is true, and off otherwise.
  const ChorusChanged(this.on);

  /// Whether the chorus is now on.
  final bool on;

  @override
  bool operator ==(Object other) => other is ChorusChanged && other.on == on;

  @override
  int get hashCode => Object.hash(ChorusChanged, on);

  @override
  String toString() => 'ChorusChanged($on)';
}

/// The gain was set.
final class GainChanged extends SynthEvent {
  /// The gain was set to [gain].
  const GainChanged(this.gain);

  /// The new gain, from 0 to 10.
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
  /// The device output opened.
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
  /// The device output closed, after ringing out when [ringOut] is true.
  const Stopped({required this.ringOut});

  /// Whether the notes faded before the output closed.
  final bool ringOut;

  @override
  bool operator ==(Object other) => other is Stopped && other.ringOut == ringOut;

  @override
  int get hashCode => Object.hash(Stopped, ringOut);

  @override
  String toString() => 'Stopped(ringOut: $ringOut)';
}

/// Samples were rendered without the device.
final class Rendered extends SynthEvent {
  /// [frames] stereo frames were rendered.
  const Rendered(this.frames);

  /// How many stereo frames were rendered.
  final int frames;

  @override
  bool operator ==(Object other) => other is Rendered && other.frames == frames;

  @override
  int get hashCode => Object.hash(Rendered, frames);

  @override
  String toString() => 'Rendered($frames)';
}

/// The synth was closed and freed.
final class Closed extends SynthEvent {
  /// The synth was closed and freed.
  const Closed();

  @override
  bool operator ==(Object other) => other is Closed;

  @override
  int get hashCode => (Closed).hashCode;

  @override
  String toString() => 'Closed()';
}
