## 0.1.0

First release.

- `Synth` plays SF2 SoundFonts on iOS and Android through FluidSynth 2.6.2, over `dart:ffi`, with 256 MIDI channels.
- SoundFonts load from assets (`AssetSoundFont`) or from files (`FileSoundFont`), and list their presets.
- `noteOn` takes `cents`, which detunes one note without moving the notes already sounding.
- Reverb, chorus and gain, each settable at any time.
- `start` and `stop` open and close the device output, and `stop(ringOut: true)` lets the notes fade first. Every call takes effect in the order it was made.
- `render` renders samples without the device.
- `AudioSessionPolicy` sets the iOS audio session as `playback`, `playbackMixing`, `playAndRecord` or `manual`. `playAndRecord` plays while the app records.
- `Synth.silent` and `package:khuur_synth/testing.dart` test code that plays music on a host machine.
- `LICENSE` is in the format Flutter's tool reads, so an app's licence page lists khuur_synth, FluidSynth and each library it bundles by name.
