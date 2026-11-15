/// The events a synth from `Synth.silent` reports, for tests of code that
/// plays through a synth.
///
/// A silent synth checks every argument and orders every call as a real one
/// does, makes no sound, and runs on a host machine. Collect its events and
/// compare them with what the code should have played.
///
/// ```dart
/// test('the tune starts on middle C', () async {
///   final events = <SynthEvent>[];
///   final synth = await Synth.silent(onEvent: events.add);
///   await playTune(synth);
///   expect(events, contains(const NoteOn(channel: 0, key: 60, velocity: 90, cents: 0)));
/// });
/// ```
library;

export 'src/synth_event.dart';
