# Contributing to khuur_synth

This guide is for working on the plugin itself. To use it in an app, read the [README](README.md).

## Set up

You need Flutter 3.47 or later. iOS builds need Xcode, and Android builds need the Android SDK. Nothing else is needed for the unit tests, which run on the host.

```bash
flutter pub get
```

That also resolves the example app's packages.

## Checks

Every change passes these. CI runs them on each pull request, with `--output=none` so the formatter changes nothing there.

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter pub publish --dry-run
```

The formatter's page width is 120, set in `analysis_options.yaml` and in the example's own. `public_member_api_docs` is on, so every public member in `lib/` needs a dartdoc comment, internal ones in `lib/src/` included.

To see the score pub.dev will give, run pana. It should stay at 160/160.

```bash
dart pub global activate pana
pana --no-warning .
```

### On a device

The unit tests run over a fake engine and never reach FluidSynth. The example's integration test does. It loads a real SoundFont, measures the pitch of detuned notes in a render, plays through the device and runs two synths at once. Run it on an iOS simulator or device and an Android emulator or device after any change under `lib/src/fluid/`, `ios/` or `android/`.

```bash
cd example
flutter test integration_test/synth_test.dart -d <device>
flutter build ios --simulator
flutter build apk --debug
```

## Layout

| Path | What it holds |
| --- | --- |
| `lib/khuur_synth.dart` | The public API, as exports from `lib/src/`. |
| `lib/testing.dart` | The `SynthEvent` classes that `Synth.silent` reports. |
| `lib/src/synth.dart` | `Synth`. It checks every argument, runs every call in order, and tracks the device output through start, ring-out and stop. |
| `lib/src/engine.dart` | `Engine`, the narrow interface `Synth` drives, and `NoEngine`, the silent one. |
| `lib/src/fluid/fluid_engine.dart` | `FluidEngine`, the `Engine` over FluidSynth through `dart:ffi`. |
| `lib/src/fluid/fluid_bindings.dart` | Bindings that ffigen generates. Never edit it by hand. |
| `lib/src/audio_session.dart` | `AudioSessionPolicy`, and the method channel to the iOS side that sets the session. |
| `lib/src/key_tuning.dart` | Which tuning calls a detuned note needs. |
| `lib/src/asset_files.dart` | Copies an asset to a file, since FluidSynth reads from a path. |
| `ios/khuur_synth/` | The Swift package. `KhuurSynthPlugin.swift` sets the audio session and reports interruptions, and `FluidSynth.xcframework` is the vendored framework. |
| `android/` | An `ffiPlugin`. `src/main/jniLibs/` holds the vendored libraries, and `src/main/cpp/` builds a tiny library whose only job is to make the app package `libc++_shared.so`. |
| `third_party/fluidsynth/include/` | FluidSynth's headers, which ffigen reads. |
| `tool/` | `vendor_fluidsynth.sh`, which fetches and checks the binaries, and `ffigen.yaml`. |
| `test/` | Unit tests. `test/support/fake_engine.dart` logs each engine call, so a test reads the order. |
| `example/` | The example app and its integration test. |

## How a call reaches FluidSynth

`Synth` checks the arguments of every call first, so a mistake throws at the call that made it, and an `Engine` trusts what it is given.

Calls come in two kinds. Notes and settings are commands. They are quick, and `FluidEngine` makes them synchronously on the calling isolate. `load`, `unload`, `start`, `stop`, `render` and `close` are operations. They can hold FluidSynth's lock for a long time, so `FluidEngine` runs them on a helper isolate with `Isolate.run`, and they return futures.

`Synth` keeps one queue. Operations run one at a time in the order they were called. A command made while an operation runs joins the queue behind it, and a command made while the queue is empty runs at once. So every call takes effect in the order it was made, and the UI isolate never waits on the lock.

`start` and `stop` change what the synth asks of the device at once, and queue the step that brings the device there. `_Stopped`, `_Started` and `_Ringing` in `synth.dart` are those states. `test/start_stop_order_test.dart` covers the orders of calls that once went wrong.

## Adding a FluidSynth call

1. Add the function's name under `functions.include` in `tool/ffigen.yaml`.
2. Regenerate the bindings. ffigen needs libclang, which Xcode's command line tools provide on macOS. It prints warnings for FluidSynth's opaque structs, which are expected.

   ```bash
   dart run ffigen --config tool/ffigen.yaml
   dart format lib/src/fluid/fluid_bindings.dart
   ```

3. Add a method to `Engine`, and implement it in `FluidEngine`, `NoEngine` and `FakeEngine`.
4. Call it from `Synth`, after checking the arguments there. If `Synth.silent` users should see it, add a `SynthEvent` for it in `lib/src/synth_event.dart`, with `==`, `hashCode` and `toString`.
5. Test the order and the checks in `test/synth_test.dart`, and the sound in `example/integration_test/synth_test.dart`.

## Updating FluidSynth

1. In `tool/vendor_fluidsynth.sh`, set `VERSION` and the two SHA-256 sums of the release zips on the [release page](https://github.com/FluidSynth/fluidsynth/releases).
2. Run the script on macOS. It needs `curl`, `plutil`, which macOS has, and the Android NDK. Set `ANDROID_NDK_HOME` when the NDK is not under `~/Library/Android/sdk/ndk/`. It downloads both zips, refuses one whose sum differs, strips and checks the Android libraries, and copies the iOS framework and the headers. To use zips you have already downloaded, pass the folder that holds them.

   ```bash
   tool/vendor_fluidsynth.sh
   tool/vendor_fluidsynth.sh ~/Downloads
   ```

3. Regenerate the bindings as above.
4. Update every place that names a version. Search the repository for the old FluidSynth and libsndfile versions to find them all.
   - `LICENSE`, in the headers of the FluidSynth and libsndfile parts.
   - `README.md`, `AGENTS.md` and `CHANGELOG.md`.
   - `description` and `preamble` in `tool/ffigen.yaml`.
   - `test/license_test.dart`, which checks FluidSynth's source tag.

   Then update the sizes in the README's size section, and add a CHANGELOG entry.
5. Run the checks and the device test on both platforms.

## The LICENSE file

`LICENSE` serves two readers, and a change must keep both working.

- Flutter's tool splits it on lines of 80 hyphens and reads each part's first paragraph as the names it covers, one per line. That is how an app's licence page lists FluidSynth and each library. `test/license_test.dart` checks the names.
- pana, and so pub.dev, must recognise the licences in it. Its detector gives up when 50 words in a row match no known licence. The longest such run today is the header of the LGPL part, at 45 words, so keep the headers short and add no notes between the texts. Run pana after any change to `LICENSE` and check that it still lists MIT, LGPL-2.1, Apache-2.0 and BSD-3-Clause.

## Commits and pull requests

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org), such as `fix: keep the output open after a start during ring-out`. A change a user can notice gets a line in `CHANGELOG.md` under the next version.

## Releases

1. Set the new `version` in `pubspec.yaml`, and give `CHANGELOG.md` an entry for it. The pubspec is the only place the plugin's version is written.
2. Merge to `main`.
3. Push a tag that matches the version. `.github/workflows/publish.yml` runs the tests and publishes it to pub.dev through automated publishing, so nobody runs `flutter pub publish` by hand.

   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```

   The header of `publish.yml` lists the settings on pub.dev and GitHub that this needs. A tag whose version differs from the pubspec's is refused by pub.dev.
