## 0.1.0

- First release. `Synth` plays SF2 files on iOS and Android through FluidSynth 2.6.2, with per-note cents, reverb, chorus, gain, device output with ring-out, offline rendering, and `Synth.silent` for tests.
- `start` and `stop` take effect in the order they were called. A `stop` called while a `start` was still opening the output ran after it outside the queue, so `start`, `stop`, `start` left the output closed.
