import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuur_synth/khuur_synth.dart';
import 'package:khuur_synth/src/synth.dart';
import 'package:khuur_synth/testing.dart';

import 'support/fake_engine.dart';

const _ringOutLimit = Duration(seconds: 11);

void main() {
  group('start and stop made faster than the output opens', () {
    late List<SynthEvent> events;
    late Synth synth;

    void silently(void Function(FakeAsync time) body) => fakeAsync((time) {
      events = [];
      Synth.silent(onEvent: events.add).then((opened) => synth = opened);
      time.flushMicrotasks();
      body(time);
    });

    void expectStarted() => expect(() => synth.render(1), throwsStateError);

    void expectStopped(FakeAsync time) {
      var rendered = false;
      synth.render(1).then((_) => rendered = true);
      time.flushMicrotasks();
      expect(rendered, isTrue);
    }

    test('start, stop, start leaves the output open', () {
      silently((time) {
        synth.start();
        synth.stop();
        synth.start();
        time.elapse(_ringOutLimit);
        expect(events, [const Started(), const Stopped(ringOut: false), const Started()]);
        expectStarted();
      });
    });

    test('each call answers once its own step is done', () {
      silently((time) {
        final answered = <String>[];
        synth.start().then((_) => answered.add('start after $events'));
        synth.stop().then((_) => answered.add('stop after $events'));
        synth.start().then((_) => answered.add('start after $events'));
        time.flushMicrotasks();
        expect(answered, [
          'start after [Started()]',
          'stop after [Started(), Stopped(ringOut: false)]',
          'start after [Started(), Stopped(ringOut: false), Started()]',
        ]);
      });
    });

    test('five starts and stops in a row end as the last call says', () {
      silently((time) {
        synth.start();
        synth.stop();
        synth.start();
        synth.stop();
        synth.start();
        time.elapse(_ringOutLimit);
        expect(events, [
          const Started(),
          const Stopped(ringOut: false),
          const Started(),
          const Stopped(ringOut: false),
          const Started(),
        ]);
        expectStarted();
      });
    });

    test('stop, start, stop on an open output leaves it closed', () {
      silently((time) {
        synth.start();
        time.flushMicrotasks();
        events.clear();
        synth.stop();
        synth.start();
        synth.stop();
        time.elapse(_ringOutLimit);
        expect(events, [const Stopped(ringOut: false), const Started(), const Stopped(ringOut: false)]);
        expectStopped(time);
      });
    });

    test('start, stop with ring-out, start leaves the output open', () {
      silently((time) {
        synth.start();
        synth.stop(ringOut: true);
        synth.start();
        time.elapse(_ringOutLimit);
        expect(events, [const Started()]);
        expectStarted();
      });
    });

    test('a stop with ring-out made during a start closes the output once it has opened', () {
      silently((time) {
        var closed = false;
        synth.start();
        synth.stop(ringOut: true).then((_) => closed = true);
        time.flushMicrotasks();
        expect(events, [const Started()]);
        expect(closed, isFalse);
        time.elapse(_ringOutLimit);
        expect(events, [const Started(), const Stopped(ringOut: true)]);
        expect(closed, isTrue);
        expectStopped(time);
      });
    });

    test('stop, start, stop with ring-out on an open output leaves it closed', () {
      silently((time) {
        synth.start();
        time.flushMicrotasks();
        events.clear();
        synth.stop();
        synth.start();
        synth.stop(ringOut: true);
        time.elapse(_ringOutLimit);
        expect(events, [const Stopped(ringOut: false), const Started(), const Stopped(ringOut: true)]);
        expectStopped(time);
      });
    });

    test('start, stop with ring-out, stop closes the output once, at once', () {
      silently((time) {
        synth.start();
        synth.stop(ringOut: true);
        synth.stop();
        time.flushMicrotasks();
        expect(events, [const Started(), const Stopped(ringOut: false)]);
        time.elapse(_ringOutLimit);
        expect(events, hasLength(2));
      });
    });

    test('a stop made during a start answers when a close follows it', () {
      silently((time) {
        Object? stopError;
        var stopped = false;
        synth.start();
        synth.stop().then((_) => stopped = true).catchError((Object e) {
          stopError = e;
          return false;
        });
        synth.close();
        time.flushMicrotasks();
        expect(stopError, isNull);
        expect(stopped, isTrue);
        expect(events.last, const Closed());
      });
    });
  });

  group('a start that fails', () {
    late List<String> log;
    late FakeEngine engine;
    late Synth synth;

    setUp(() {
      log = [];
      engine = FakeEngine(log)..openErrors.add(const AudioOutputFailed('busy'));
      synth = synthOver(engine, session: FakeSession(log));
    });

    test('under a stop and a start leaves the second start its open output', () async {
      final first = synth.start();
      final stop = synth.stop();
      final second = synth.start();
      await expectLater(first, throwsA(isA<AudioOutputFailed>()));
      await stop;
      await second;
      expect(log.where((l) => l == 'openAudio'), hasLength(2));
      expect(log, isNot(contains('closeAudio')));
      expect(() => synth.render(1), throwsStateError);

      await synth.stop();
      expect(log.last, 'closeAudio');
    });

    test('under a stop with ring-out leaves the output closed, and the stop answers', () {
      fakeAsync((time) {
        Object? startError;
        var stopped = false;
        var rendered = false;
        synth.start().catchError((Object e) {
          startError = e;
        });
        synth.stop(ringOut: true).then((_) => stopped = true);
        time.elapse(_ringOutLimit);
        expect(startError, isA<AudioOutputFailed>());
        expect(stopped, isTrue);
        expect(log, isNot(contains('closeAudio')));
        synth.render(1).then((_) => rendered = true);
        time.flushMicrotasks();
        expect(rendered, isTrue);
      });
    });
  });

  test('a session reset heard by an output since closed leaves the next one alone', () async {
    final log = <String>[];
    final session = FakeSession(log);
    final synth = synthOver(FakeEngine(log), session: session);
    await synth.start();
    unawaited(synth.stop());
    session.reset();
    await synth.start();
    await pumpEventQueue();
    expect(log.where((l) => l == 'openAudio'), hasLength(2));
    expect(log.where((l) => l == 'closeAudio'), hasLength(1));
  });
}
