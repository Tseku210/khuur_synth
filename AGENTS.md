# AGENTS.md

khuur_synth is a Flutter plugin that plays SF2 SoundFonts on iOS and Android through FluidSynth 2.6.2 over `dart:ffi`. This file is for coding agents. The first part is for agents writing an app that uses the plugin, and the second for agents changing the plugin. [README.md](README.md) and [CONTRIBUTING.md](CONTRIBUTING.md) have the full story.

## Using khuur_synth in an app

- Import `package:khuur_synth/khuur_synth.dart`. Tests also import `package:khuur_synth/testing.dart` for the event classes.
- `Synth.open()` works only on iOS and Android. On desktop and in `flutter test` it throws `SynthUnavailable`, and on the web the package does not compile, so code that plays should take a `Synth` as a parameter, and tests pass `await Synth.silent(onEvent: events.add)` and compare the events.
- A synth's life runs `open`, then `load`, then `select`, then `start`, then `noteOn` and `noteOff`, then `stop`, then `close`. `start` and `stop` may repeat. Nothing sounds without `start`, and a channel with no `select` plays nothing.
- Declare each SoundFont asset in the app's `pubspec.yaml` and load it with `AssetSoundFont('assets/name.sf2')`. Use `FileSoundFont(path)` for a downloaded file. iOS reads SF2 only, not SF3.
- Give each instrument its own channel. A channel plays one preset at a time.
- `controlChange(channel:, controller:, value:)` sends a MIDI controller, such as 11 for expression or 64 for the sustain pedal. Notes already sounding follow it.
- Ranges are checked at the call and throw `RangeError`, or fail the future of an asynchronous call. Channels run 0 to 255, keys, programs, controllers and controller values 0 to 127, velocity 1 to 127, banks 0 to 16383, `cents` -1200 to 1200, `gain` 0 to 10.
- `load`, `unload`, `start`, `stop`, `render` and `close` return futures, so await them. Notes and setters are synchronous and need no await, even right after an unawaited `start`, since every call runs in the order it was made.
- Errors to catch are the sealed `SynthException`, which is one of `SynthUnavailable`, `SoundFontLoadFailed`, `PresetNotFound` and `AudioOutputFailed`.
- An app that also records on iOS, such as a tuner, opens the synth with `session: AudioSessionPolicy.playAndRecord`.
- Close the synth when its screen goes, in `dispose`.
- The app ships FluidSynth under the LGPL. Flutter's licence page lists it with no extra code. Do not suggest linking it statically.

## Changing the plugin

### Commands

Run these from the repository root before any commit. CI runs the same checks, with `--output=none` so the formatter changes nothing.

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter pub publish --dry-run
```

After a change under `lib/src/fluid/`, `ios/` or `android/`, also run the device test in `example/` with `flutter test integration_test/synth_test.dart -d <device>`, and build with `flutter build ios --simulator` and `flutter build apk --debug` there.

### Where things are

- `lib/src/synth.dart` is the public `Synth`, the call queue and the output's states.
- `lib/src/engine.dart` is the `Engine` interface. `FluidEngine` in `lib/src/fluid/fluid_engine.dart` implements it over FFI, `NoEngine` makes no sound, and `test/support/fake_engine.dart` logs each call for the unit tests.
- `lib/src/fluid/fluid_bindings.dart` is generated. Change `tool/ffigen.yaml` and run `dart run ffigen --config tool/ffigen.yaml` followed by `dart format lib/src/fluid/fluid_bindings.dart`.
- `ios/khuur_synth/` is a Swift package with the vendored `FluidSynth.xcframework`. There is no podspec, and iOS uses Swift Package Manager only.
- `android/src/main/jniLibs/` holds the vendored `.so` files. Replace them only through `tool/vendor_fluidsynth.sh`, which checks their SHA-256 sums, dependencies and 16 KB alignment.

### Rules

- Every public member in `lib/` has a dartdoc comment. The `public_member_api_docs` lint enforces it.
- The page width is 120.
- `Synth` checks every argument before it reaches an `Engine`. An `Engine` never validates.
- A new engine method goes into `Engine`, `FluidEngine`, `NoEngine` and `FakeEngine`, and usually gets a `SynthEvent`.
- Slow FluidSynth calls, the ones that take its lock for long, run in `Isolate.run`. Quick ones run on the calling isolate.
- In tests, `stop(ringOut: true)` waits on a real timer for at least 100 ms, even on a silent synth or `NoEngine`. Use `fakeAsync` and elapse it, as `test/synth_test.dart` does.
- Keep `LICENSE` in Flutter's format, parts split by 80 hyphens, each opening with its names one per line. Keep each part's header short, under 50 words with no notes between the texts, or pub.dev stops recognising the licences. `test/license_test.dart` checks the names, and pana checks the rest.
- Do not edit the vendored binaries or the generated bindings by hand.
- Commits follow Conventional Commits. A change users can notice gets a CHANGELOG line.
