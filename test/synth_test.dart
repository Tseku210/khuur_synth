import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuur_synth/khuur_synth.dart';
import 'package:khuur_synth/src/synth.dart';

import 'support/fake_engine.dart';

const piano = AssetSoundFont('assets/piano.sf2');

void main() {
  late List<String> log;
  late FakeEngine engine;
  late FakeSession session;
  late Synth synth;

  setUp(() {
    log = [];
    engine = FakeEngine(log);
    session = FakeSession(log);
    synth = synthOver(engine, session: session, policy: AudioSessionPolicy.playback);
    log.clear();
  });

  test('a new synth applies its reverb, chorus and gain', () {
    final fresh = <String>[];
    synthOver(FakeEngine(fresh), reverb: null, chorus: false, gain: 1);
    expect(fresh, ['setReverb null', 'setChorus false', 'setGain 1.0']);
  });

  group('the command gate', () {
    test('notes made while a load runs reach the engine after it, in order', () async {
      engine.loadGate = Completer();
      synth.noteOn(channel: 0, key: 60);
      final loading = synth.load(piano);
      synth.noteOn(channel: 0, key: 64);
      synth.allNotesOff();
      expect(log, ['noteOn 0 60 100', 'load $piano']);

      engine.loadGate!.complete();
      await loading;
      expect(log, ['noteOn 0 60 100', 'load $piano', 'noteOn 0 64 100', 'allNotesOff']);
    });

    test('a call made after a wait runs after it and before the next one', () async {
      engine.loadGate = Completer();
      unawaited(synth.load(piano));
      synth.noteOn(channel: 1, key: 60);
      final second = synth.load(const FileSoundFont('/b.sf2'));
      engine.loadGate!.complete();
      await second;
      expect(log, ['load $piano', 'noteOn 1 60 100', 'load ${const FileSoundFont('/b.sf2')}']);
    });

    test('close waits for a load in flight, and later calls throw', () async {
      engine.loadGate = Completer();
      final loading = synth.load(piano);
      final closing = synth.close();
      expect(synth.close(), same(closing));
      expect(() => synth.noteOn(channel: 0, key: 60), throwsStateError);
      engine.loadGate!.complete();
      await loading;
      await closing;
      expect(log, ['load $piano', 'close']);
    });
  });

  group('SoundFonts and presets', () {
    test('select plays a preset the file has', () async {
      final font = await synth.load(piano);
      synth.select(channel: 3, font: font, program: 0);
      expect(log.last, 'select 3 1 0:0');
      expect(font.presets, [const Preset(bank: 0, program: 0, name: 'Piano')]);
    });

    test('a missing preset throws and leaves the channel silent', () async {
      final font = await synth.load(piano);
      expect(() => synth.select(channel: 3, font: font, program: 40), throwsA(isA<PresetNotFound>()));
      expect(log.last, 'unset 3');
    });

    test('a font from another synth or one unloaded is refused', () async {
      final other = synthOver(FakeEngine([]));
      final foreign = await other.load(piano);
      expect(() => synth.select(channel: 0, font: foreign, program: 0), throwsArgumentError);

      final font = await synth.load(piano);
      synth.select(channel: 2, font: font, program: 0);
      await synth.unload(font);
      expect(log.sublist(log.length - 2), ['unset 2', 'unload 1']);
      expect(() => synth.select(channel: 2, font: font, program: 0), throwsArgumentError);
    });

    test('a load that fails throws SoundFontLoadFailed', () async {
      final silent = await Synth.silent(presets: (s) => throw SoundFontLoadFailed(s, 'unreadable'));
      expect(silent.load(piano), throwsA(isA<SoundFontLoadFailed>()));
    });
  });

  group('cents', () {
    test('the first detuned note of a channel tunes its key and activates the tuning once', () {
      synth.noteOn(channel: 0, key: 64, cents: -13.7);
      synth.noteOn(channel: 0, key: 64, cents: -13.7);
      synth.noteOn(channel: 0, key: 67, cents: 2);
      synth.noteOn(channel: 0, key: 64, cents: 0);
      expect(log, [
        'tuneKey 0 64 -13.7',
        'activateTuning 0',
        'noteOn 0 64 100',
        'noteOn 0 64 100',
        'tuneKey 0 67 2.0',
        'noteOn 0 67 100',
        'tuneKey 0 64 0.0',
        'noteOn 0 64 100',
      ]);
    });

    test('a channel never detuned gets no tuning', () {
      synth.noteOn(channel: 5, key: 60, cents: 0);
      expect(log, ['noteOn 5 60 100']);
    });
  });

  group('the device output', () {
    test('start sets the session around the driver, once', () async {
      await Future.wait([synth.start(), synth.start()]);
      expect(log, ['activate playback', 'openAudio', 'activate playback']);
    });

    test('a start that fails throws and can be tried again', () async {
      engine.openError = const AudioOutputFailed('busy');
      await expectLater(synth.start(), throwsA(isA<AudioOutputFailed>()));
      engine.openError = null;
      await synth.start();
      expect(log.where((l) => l == 'openAudio'), hasLength(2));
    });

    test('stop cuts every sound and closes the driver', () async {
      await synth.start();
      log.clear();
      await synth.stop();
      expect(log, ['allSoundsOff', 'closeAudio']);
    });

    test('stop with ring-out closes once the voices have faded', () {
      fakeAsync((time) {
        synth.start();
        time.flushMicrotasks();
        log.clear();
        engine.voices = 3;
        var closed = false;
        synth.stop(ringOut: true).then((_) => closed = true);
        time.elapse(const Duration(seconds: 2));
        expect(log, ['allNotesOff']);

        engine.voices = 0;
        time.elapse(const Duration(milliseconds: 150));
        expect(log, ['allNotesOff', 'closeAudio']);
        expect(closed, isTrue);
      });
    });

    test('ring-out gives up after 10 s', () {
      fakeAsync((time) {
        synth.start();
        time.flushMicrotasks();
        engine.voices = 1;
        synth.stop(ringOut: true);
        time.elapse(const Duration(milliseconds: 9900));
        expect(log, isNot(contains('closeAudio')));
        time.elapse(const Duration(milliseconds: 200));
        expect(log, contains('closeAudio'));
      });
    });

    test('a start while ringing out keeps the output open', () {
      fakeAsync((time) {
        synth.start();
        time.flushMicrotasks();
        engine.voices = 1;
        synth.stop(ringOut: true);
        time.elapse(const Duration(milliseconds: 100));
        synth.start();
        engine.voices = 0;
        time.elapse(const Duration(seconds: 1));
        expect(log.where((l) => l == 'openAudio'), hasLength(1));
        expect(log, isNot(contains('closeAudio')));
      });
    });

    test('a session reset reopens an open output', () async {
      await synth.start();
      log.clear();
      session.reset();
      await pumpEventQueue();
      expect(log, ['closeAudio', 'activate playback', 'openAudio', 'activate playback']);
    });

    test('render runs only while stopped', () async {
      expect((await synth.render(10)).length, 20);
      await synth.start();
      expect(() => synth.render(10), throwsStateError);
    });

    test('close closes the engine, output included', () async {
      await synth.start();
      log.clear();
      await synth.close();
      expect(log, ['close']);
    });
  });

  test('arguments out of range are refused at the call', () async {
    expect(() => synth.noteOn(channel: 256, key: 60), throwsRangeError);
    expect(() => synth.noteOn(channel: 0, key: 128), throwsRangeError);
    expect(() => synth.noteOn(channel: 0, key: 60, velocity: 0), throwsRangeError);
    expect(() => synth.noteOn(channel: 0, key: 60, cents: double.nan), throwsRangeError);
    expect(() => synth.gain = 11, throwsRangeError);
    expect(() => synth.reverb = const Reverb(roomSize: 2), throwsRangeError);
    expect(log, isEmpty);
  });

  test('Synth.open says FluidSynth is unavailable on a host', () {
    expect(Synth.open(), throwsA(isA<SynthUnavailable>()));
  });
}
