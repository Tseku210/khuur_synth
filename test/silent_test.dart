import 'package:flutter_test/flutter_test.dart';
import 'package:khuur_synth/khuur_synth.dart';
import 'package:khuur_synth/testing.dart';

void main() {
  test('every call on a silent synth reports one event, in order', () async {
    final events = <SynthEvent>[];
    final synth = await Synth.silent(onEvent: events.add);
    const source = AssetSoundFont('assets/piano.sf2');

    final font = await synth.load(source);
    synth.select(channel: 0, font: font, program: 0);
    synth.noteOn(channel: 0, key: 64, velocity: 90, cents: -13.7);
    synth.controlChange(channel: 0, controller: 11, value: 40);
    synth.noteOff(channel: 0, key: 64);
    synth.allNotesOff();
    synth.allSoundsOff();
    synth.reverb = null;
    synth.chorus = false;
    synth.gain = 1;
    await synth.render(441);
    await synth.start();
    await synth.stop(ringOut: true);
    await synth.unload(font);
    await synth.close();

    expect(events, [
      const Loaded(source),
      const Selected(channel: 0, source: source, bank: 0, program: 0),
      const NoteOn(channel: 0, key: 64, velocity: 90, cents: -13.7),
      const ControlChanged(channel: 0, controller: 11, value: 40),
      const NoteOff(channel: 0, key: 64),
      const AllNotesOff(),
      const AllSoundsOff(),
      const ReverbChanged(null),
      const ChorusChanged(false),
      const GainChanged(1),
      const Rendered(441),
      const Started(),
      const Stopped(ringOut: true),
      const Unloaded(source),
      const Closed(),
    ]);
  });

  test('a silent synth offers General MIDI unless told otherwise', () async {
    final synth = await Synth.silent();
    final font = await synth.load(const FileSoundFont('/gm.sf2'));
    expect(font.presets, hasLength(129));
    expect(() => synth.select(channel: 9, font: font, program: 0, bank: 128), returnsNormally);

    final custom = await Synth.silent(presets: (_) => const [Preset(bank: 0, program: 42, name: 'Cello')]);
    final cello = await custom.load(const FileSoundFont('/cello.sf2'));
    expect(() => custom.select(channel: 0, font: cello, program: 0), throwsA(isA<PresetNotFound>()));
  });
}
