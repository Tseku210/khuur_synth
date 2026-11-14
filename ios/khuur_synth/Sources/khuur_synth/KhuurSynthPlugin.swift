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
      try session.setCategory(.playback, mode: .default, options: policy == "playbackMixing" ? [.mixWithOthers] : [])
      try session.setActive(true)
      result(nil)
    } catch {
      result(FlutterError(code: "session", message: error.localizedDescription, details: nil))
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
