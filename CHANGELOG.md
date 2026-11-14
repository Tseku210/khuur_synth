## 0.1.0

- First release. `Synth` plays SF2 files on iOS and Android through FluidSynth 2.6.2, with per-note cents, reverb, chorus, gain, device output with ring-out, offline rendering, and `Synth.silent` for tests.
- `start` and `stop` take effect in the order they were called. A `stop` called while a `start` was still opening the output ran after it outside the queue, so `start`, `stop`, `start` left the output closed.
- `AudioSessionPolicy.playAndRecord` plays while the app records. The iOS driver opens in its low-latency mode so the input stays open, and the plugin keeps the recording's `.playAndRecord` mode, options and IO buffer duration.
- `LICENSE` is in the format Flutter's tool reads, so an app's licence page lists khuur_synth, FluidSynth and each library it bundles by name.
