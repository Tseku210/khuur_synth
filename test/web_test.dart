@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:khuur_synth/khuur_synth.dart';

void main() {
  test('Synth.open says khuur_synth does not run on the web', () {
    expect(
      Synth.open(),
      throwsA(isA<SynthUnavailable>().having((e) => e.message, 'message', 'khuur_synth does not run on the web.')),
    );
  });

  test('Synth.silent plays on the web', () async {
    final synth = await Synth.silent();
    await synth.load(const AssetSoundFont('assets/piano.sf2'));
    synth.noteOn(channel: 0, key: 60, velocity: 100);
    await synth.close();
  });
}
