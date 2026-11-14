import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'synth_exception.dart';

/// How a synth sets the iOS audio session when it starts. Android has no
/// session, and the plugin does not request audio focus there.
enum AudioSessionPolicy {
  /// `.playback` without mixing: other apps' audio stops, and the ring switch
  /// does not mute the synth.
  playback,

  /// `.playback` mixed with other apps' audio.
  playbackMixing,

  /// `.playAndRecord`, to play while the app records, as when it listens to
  /// the microphone.
  ///
  /// The synth keeps the `.playAndRecord` session the recording set, with
  /// its mode, options and IO buffer duration, so a recording in
  /// `.measurement` mode stays in it. Until a recording sets one, the synth
  /// sets `.playAndRecord` itself, in mode `.default`, out of the speaker and
  /// to Bluetooth headphones through A2DP.
  ///
  /// FluidSynth's driver opens in its low-latency mode, the one in which it
  /// asks for `.playAndRecord` rather than `.playback`, so the input stays
  /// open. The driver still sets its own mode, options and IO buffer as it
  /// opens, and the synth sets back the recording's once it has.
  playAndRecord,

  /// The plugin never touches the session, and the app sets it. FluidSynth's
  /// driver still sets `.playback` mixed with others as it opens, so an app
  /// that wants another session sets it again once `start` returns.
  manual,
}

/// The iOS audio session as a synth needs it.
abstract interface class AudioSession {
  /// Throws `AudioOutputFailed`.
  Future<void> activate(AudioSessionPolicy policy);

  /// Fires when an open output has gone quiet and must be reopened: after an
  /// interruption ends, and after the media services reset.
  Stream<void> get resets;
}

final class PlatformAudioSession implements AudioSession {
  PlatformAudioSession._();

  static final instance = PlatformAudioSession._();

  static const _methods = MethodChannel('khuur_synth/session');
  static const _events = EventChannel('khuur_synth/session_events');

  @override
  Future<void> activate(AudioSessionPolicy policy) async {
    if (defaultTargetPlatform != TargetPlatform.iOS || policy == AudioSessionPolicy.manual) return;
    try {
      await _methods.invokeMethod<void>('activate', policy.name);
    } on PlatformException catch (e) {
      throw AudioOutputFailed('The audio session would not activate: ${e.message}');
    }
  }

  @override
  late final Stream<void> resets = defaultTargetPlatform == TargetPlatform.iOS
      ? _events.receiveBroadcastStream().map((_) {})
      : const Stream<void>.empty();
}

final class NoAudioSession implements AudioSession {
  const NoAudioSession();

  @override
  Future<void> activate(AudioSessionPolicy policy) async {}

  @override
  Stream<void> get resets => const Stream<void>.empty();
}
