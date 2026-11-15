import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An app's licence page lists this file as Flutter's tool reads it: split on
/// a line of 80 hyphens, each part's first paragraph is the names it covers,
/// one a line, and the rest is the licence.
List<({List<String> names, String text})> _asFlutterReadsIt(String license) => [
  for (final part in license.split('\n${'-' * 80}\n'))
    switch (part.indexOf('\n\n')) {
      -1 => (names: <String>[], text: part),
      final split => (names: part.substring(0, split).split('\n'), text: part.substring(split + 2)),
    },
];

void main() {
  final parts = _asFlutterReadsIt(File('LICENSE').readAsStringSync());

  test('the licence page names the plugin and each library it ships', () {
    expect(parts.map((part) => part.names), [
      ['khuur_synth'],
      ['fluidsynth', 'libsndfile'],
      ['oboe'],
      ['libogg'],
      ['libvorbis'],
      ['flac'],
      ['opus'],
    ]);
  });

  test('FluidSynth carries the LGPL and says where its source is', () {
    final fluidSynth = parts.singleWhere((part) => part.names.contains('fluidsynth')).text;
    expect(fluidSynth, contains('GNU LESSER GENERAL PUBLIC LICENSE'));
    expect(fluidSynth, contains('https://github.com/FluidSynth/fluidsynth, tag v2.6.2'));
  });
}
