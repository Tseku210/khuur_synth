import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:khuur_synth/khuur_synth.dart';

const piano = AssetSoundFont('assets/piano.sf2');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled piano loads with its presets', () async {
    final synth = await Synth.open();
    final font = await synth.load(piano);
    expect(font.presets.map((p) => (p.bank, p.program)), contains((0, 0)));
    await synth.close();
  });

  test('cents detune the struck note by that much', () async {
    final plain = await _pitch(64, 0);
    final raised = await _pitch(64, 50);
    final lowered = await _pitch(64, -13.7);
    expect(1200 * log(raised / plain) / ln2, closeTo(50, 1));
    expect(1200 * log(lowered / plain) / ln2, closeTo(-13.7, 1));
  });

  test('a note sounds through the device and rings out', () async {
    final synth = await Synth.open();
    synth.select(channel: 0, font: await synth.load(piano), program: 0);
    await synth.start();
    synth.noteOn(channel: 0, key: 60);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final watch = Stopwatch()..start();
    await synth.stop(ringOut: true);
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(await synth.render(4410), hasLength(8820));
    await synth.close();
  });

  test('two synths play at once', () async {
    final synths = [await Synth.open(), await Synth.open()];
    for (final synth in synths) {
      synth.select(channel: 0, font: await synth.load(piano), program: 0);
      await synth.start();
      synth.noteOn(channel: 0, key: 67);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final synth in synths) {
      await synth.close();
    }
  });

  test('a missing file fails to load', () async {
    final synth = await Synth.open();
    await expectLater(synth.load(const FileSoundFont('/nowhere.sf2')), throwsA(isA<SoundFontLoadFailed>()));
    await synth.close();
  });
}

/// The strongest frequency near [key]'s, from a dry render.
Future<double> _pitch(int key, double cents) async {
  final synth = await Synth.open(reverb: null, chorus: false);
  synth.select(channel: 0, font: await synth.load(piano), program: 0);
  synth.noteOn(channel: 0, key: key, velocity: 100, cents: cents);
  await synth.render(4410);
  final samples = await synth.render(32768);
  await synth.close();
  return _peak(samples, 440 * pow(2, (key - 69) / 12).toDouble());
}

double _peak(Float32List stereo, double near) {
  final n = stereo.length ~/ 2;
  final left = [for (var i = 0; i < n; i++) stereo[2 * i] * (0.5 - 0.5 * cos(2 * pi * i / (n - 1)))];
  var best = near;
  var bestPower = -1.0;
  for (var f = near * 0.95; f < near * 1.05; f += 0.05) {
    final w = 2 * pi * f / 44100;
    final c = 2 * cos(w);
    var s1 = 0.0;
    var s2 = 0.0;
    for (final x in left) {
      final s0 = x + c * s1 - s2;
      s2 = s1;
      s1 = s0;
    }
    final power = s1 * s1 + s2 * s2 - c * s1 * s2;
    if (power > bestPower) {
      bestPower = power;
      best = f;
    }
  }
  return best;
}
