import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khuur_synth/khuur_synth.dart';
import 'package:khuur_synth/src/audio_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Object?> asked;

  setUp(() {
    asked = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('khuur_synth/session'),
      (call) async => asked.add('${call.method} ${call.arguments}'),
    );
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('on iOS each policy but manual asks for its session by name', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    for (final policy in AudioSessionPolicy.values) {
      await PlatformAudioSession.instance.activate(policy);
    }
    expect(asked, ['activate playback', 'activate playbackMixing', 'activate playAndRecord']);
  });

  test('Android has no session to set', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    for (final policy in AudioSessionPolicy.values) {
      await PlatformAudioSession.instance.activate(policy);
    }
    expect(asked, isEmpty);
  });

  test('a session iOS refuses fails the start', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('khuur_synth/session'),
      (call) async => throw PlatformException(code: 'session', message: 'refused'),
    );
    await expectLater(
      PlatformAudioSession.instance.activate(AudioSessionPolicy.playAndRecord),
      throwsA(isA<AudioOutputFailed>()),
    );
  });
}
