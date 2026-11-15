import AVFoundation
import Flutter

/// The iOS audio session for khuur_synth. FluidSynth itself is called from Dart.
public final class KhuurSynthPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var observers: [NSObjectProtocol] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = KhuurSynthPlugin()
    let methods = FlutterMethodChannel(name: "khuur_synth/session", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: methods)
    FlutterEventChannel(name: "khuur_synth/session_events", binaryMessenger: registrar.messenger())
      .setStreamHandler(plugin)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "activate", let policy = call.arguments as? String else {
      result(FlutterMethodNotImplemented)
      return
    }
    let session = AVAudioSession.sharedInstance()
    do {
      if policy == "playAndRecord" {
        try shareWithRecording(session)
      } else {
        try session.setCategory(.playback, mode: .default, options: policy == "playbackMixing" ? [.mixWithOthers] : [])
      }
      try session.setActive(true)
      result(nil)
    } catch {
      result(FlutterError(code: "session", message: error.localizedDescription, details: nil))
    }
  }

  /// The last `.playAndRecord` session found that FluidSynth's driver did not
  /// set, and its IO buffer duration. That is the recording's session, or the
  /// plugin's own `.speaker` one when no recording has set one.
  private var held: (recording: Recording, ioBufferDuration: TimeInterval)?

  /// Keeps the `.playAndRecord` session a recording set, or sets one out of
  /// the speaker until a recording does. Dart calls it before FluidSynth's
  /// driver opens and again after, and the second call finds the session as
  /// the driver left it and sets back the one it held. Only what differs is
  /// set, since each change reconfigures the audio hardware under the
  /// recording.
  private func shareWithRecording(_ session: AVAudioSession) throws {
    if let found = Recording(session), found != .fluidSynths {
      held = (found, session.preferredIOBufferDuration)
    }
    let (recording, ioBufferDuration) = held ?? (.speaker, 0)
    if Recording(session) != recording {
      try session.setCategory(.playAndRecord, mode: recording.mode, options: recording.options)
    }
    if ioBufferDuration > 0, session.preferredIOBufferDuration != ioBufferDuration {
      try session.setPreferredIOBufferDuration(ioBufferDuration)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
        let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
        if type == .ended { self?.sink?("interruptionEnded") }
      },
      center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
        self?.sink?("mediaServicesReset")
      },
    ]
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
    sink = nil
    return nil
  }
}

/// A `.playAndRecord` session's mode and options.
private struct Recording: Equatable {
  let mode: AVAudioSession.Mode
  let options: AVAudioSession.CategoryOptions

  /// What FluidSynth's driver sets as it opens in its low-latency mode.
  static let fluidSynths = Recording(mode: .default, options: [.mixWithOthers, .defaultToSpeaker])

  /// Out of the speaker rather than the earpiece, and to Bluetooth
  /// headphones in full quality.
  static let speaker = Recording(mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])

  init(mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) {
    self.mode = mode
    self.options = options
  }

  init?(_ session: AVAudioSession) {
    guard session.category == .playAndRecord else { return nil }
    self.init(mode: session.mode, options: session.categoryOptions)
  }
}
