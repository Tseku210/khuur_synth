# khuur_synth

Plays SoundFonts on iOS and Android with [FluidSynth](https://www.fluidsynth.org) 2.6.2, called from Dart through `dart:ffi`.

A `Synth` is one FluidSynth synthesizer with 256 MIDI channels. It loads SF2 files from assets or from disk, plays notes on any channel with any preset, can detune each note by cents, and sounds through the device or renders samples without it. The same synth sounds the same on both platforms, because both run FluidSynth.

The plugin bundles FluidSynth's official release binaries, so an app needs no native toolchain of its own beyond what Flutter already uses.

## Requirements

- iOS 15 or later, with Swift Package Manager. The plugin has no CocoaPods podspec, so an app that has turned Swift Package Manager off cannot use it on iOS. Swift Package Manager is on by default in Flutter 3.47 and later. See [Flutter's guide](https://docs.flutter.dev/to/spm) to check or turn it on.
- Android API 24 (Android 7.0) or later. Set `minSdk = 24` or higher in the app's `android/app/build.gradle.kts`.
- Flutter 3.47 or later.

Only iOS and Android are supported. On any other platform, and in `flutter test` on a host machine, `Synth.open` throws `SynthUnavailable`. Use `Synth.silent` there.

## Install

```bash
flutter pub add khuur_synth
```

Then add a SoundFont to the app's assets in `pubspec.yaml`.

```yaml
flutter:
  assets:
    - assets/piano.sf2
```

## Play a note

```dart
import 'package:khuur_synth/khuur_synth.dart';

Future<void> playMiddleC() async {
  final synth = await Synth.open();
  final piano = await synth.load(const AssetSoundFont('assets/piano.sf2'));
  synth.select(channel: 0, font: piano, program: 0);
  await synth.start();

  synth.noteOn(channel: 0, key: 60, velocity: 90);
  await Future<void>.delayed(const Duration(seconds: 1));
  synth.noteOff(channel: 0, key: 60);

  await synth.stop(ringOut: true);
  await synth.close();
}
```

`start` opens the device output and `stop` closes it. With `ringOut: true` the notes are released first and the output closes once the last one has faded, or after 10 seconds. Open the output while something plays and close it when the music ends, so the app holds no audio output while it is quiet.

The [example app](https://github.com/Tseku210/khuur_synth/tree/main/example) loads a piano, lists its presets, and plays a chord in equal temperament or with a pure third and fifth.

## The API

- `Synth.open({reverb, chorus, gain, session})` makes a synth. `reverb` is a `Reverb` or null for none, `chorus` is on or off, and `gain` runs from 0 to 10, 0.2 by default as in FluidSynth. Each can be changed later through the setter of the same name. `session` is the iOS audio session policy, described below.
- `load(source)` reads an `AssetSoundFont(key)` or a `FileSoundFont(path)` and answers a `LoadedSoundFont` with its `presets`. `unload(font)` frees it and silences the channels that played from it.
- `select(channel:, font:, program:, bank:)` sets what a channel plays. A preset the file lacks throws `PresetNotFound`.
- `noteOn(channel:, key:, velocity:, cents:)`, `noteOff`, `allNotesOff` and `allSoundsOff` play.
- `render(frames)` answers interleaved stereo float samples at 44.1 kHz while the synth is stopped, for tests and bounces.
- `Synth.silent()` runs every rule of a real synth and makes no sound. Its `onEvent` hears each call as a `SynthEvent`, from `package:khuur_synth/testing.dart`, so code that plays music can be tested on a host machine.

Errors are the sealed `SynthException`, which is one of `SynthUnavailable`, `SoundFontLoadFailed`, `PresetNotFound` and `AudioOutputFailed`. Arguments out of range throw a `RangeError` at the call.

### Detuned notes

`cents` detunes one note, from -1200 to 1200, without touching the notes already sounding. Use it for just intonation, for instruments tuned away from 440 Hz, or for quarter tones. Each channel keeps its own tuning, so a detuned note on one channel never moves another channel's notes. On the iPhone simulator a note asked at -13.7 cents measured -13.85 cents, and every case tried was within 3 cents.

### Calls run in order

`load`, `unload`, `start`, `stop`, `render` and `close` return futures and run one at a time, in the order they were called. A note or setting called while one of them runs waits for it in Dart and then runs, so every call takes effect in the order it was made, and no call blocks the UI isolate on FluidSynth's lock. Loading a large file can stall the audio, so load before playing.

Each synth owns its own FluidSynth synthesizer and its own output. Two synths that load the same file share its samples, which FluidSynth keeps once per process.

## The iOS audio session

`start` sets the app's `AVAudioSession` as the synth's `AudioSessionPolicy` says. Android has no audio session, and there the policy changes nothing.

| Policy | Session | Use it when |
| --- | --- | --- |
| `playback` (the default) | `.playback` without mixing | The app plays music. Other apps' audio stops, and the ring switch does not mute the synth. |
| `playbackMixing` | `.playback` mixed with other apps | The synth should sound over other apps' audio. |
| `playAndRecord` | `.playAndRecord` | The app records while it plays, as when it listens to the microphone. |
| `manual` | Left alone | The app sets the session itself. |

Some details matter for apps that also record.

- FluidSynth's driver sets the session itself whenever it opens, to `.playback` mixed with others. The plugin sets its policy again once the driver is open. With `manual`, set your own session again after `start` returns.
- `playback` and `playbackMixing` move a session that a recording left in a record category to playback. Set the record category again before you record.
- To play while recording, set `.playAndRecord` for the recording and open the synth with `AudioSessionPolicy.playAndRecord`. The driver then opens in its low-latency mode, the one in which it asks for `.playAndRecord`, so the input stays open. The driver still sets its own mode, options and IO buffer duration as it opens, and the plugin then sets back the recording's, so a recording in `.measurement` mode stays in it. Until a recording has set `.playAndRecord`, the plugin sets it in mode `.default`, out of the speaker and to Bluetooth headphones through A2DP.
- After an interruption ends or the media services reset, a started synth opens its output again by itself.

## Platform notes

### iOS

- Only SF2 files load. The official FluidSynth framework is built without SF3 support.
- FluidSynth ships as a dynamic framework inside the plugin's Swift package, so nothing is downloaded at build time.

### Android

- SF2 files load. The Android release also links libsndfile with Vorbis, which FluidSynth needs for SF3, but SF3 has not been tried yet.
- Audio goes out through Oboe. The plugin does not request audio focus, so the app does that if it needs to.
- The plugin bundles `libc++_shared.so` through a small native library of its own, built by the app's NDK, so it merges with any other plugin's copy.
- The libraries are built for arm64-v8a, armeabi-v7a and x86_64, and every one is aligned for 16 KB pages.

## Size

The FluidSynth libraries and their dependencies add about 2.9 MB for arm64-v8a on Android, plus the NDK's `libc++_shared.so` when the app has no copy yet, and about 2.6 MB on iOS. SoundFonts are the app's own and add their own size.

## The bundled binaries

The plugin ships the official FluidSynth 2.6.2 release binaries, unmodified apart from removed debug symbols. `tool/vendor_fluidsynth.sh` fetches the two release zips from [the release page](https://github.com/FluidSynth/fluidsynth/releases/tag/v2.6.2), checks each against a pinned SHA-256, strips the Android libraries, and checks their dependencies and alignment. Run it to update or to reproduce the binaries. `tool/ffigen.yaml` generates the Dart bindings from the headers it copies.

## Licences and the LGPL

The plugin's own code is MIT. FluidSynth is under the GNU Lesser General Public License 2.1 or later, and so is libsndfile, which the Android build bundles. The other bundled libraries, Oboe, libogg, libvorbis, FLAC and Opus, are under Apache-2.0 and BSD-3-Clause. `LICENSE` holds every text.

FluidSynth is linked dynamically on both platforms, as a shared library on Android and as a dynamic framework on iOS, and the plugin calls it through `dart:ffi`. The binaries are the unmodified upstream release, whose source is at https://github.com/FluidSynth/fluidsynth, tag `v2.6.2`. libsndfile's source is at https://github.com/libsndfile/libsndfile, tag `1.2.2`.

An app that ships this plugin distributes those LGPL libraries, so it takes on the LGPL's conditions for them. In practice that means the following.

- Say in the app that it uses FluidSynth, and on Android libsndfile, under the LGPL, and include the licence text. A Flutter app does this without code of its own. `LICENSE` is in the format Flutter's tool reads, so the licence page that `showLicensePage` opens lists `khuur_synth`, `fluidsynth`, `libsndfile`, `oboe`, `libogg`, `libvorbis`, `flac` and `opus`, each with its licence.
- Make the libraries' source available, for example by linking to the tags above in the app's notices or documentation.
- Keep the libraries replaceable. Do not link FluidSynth statically or merge it into the app's own binary, and do not forbid, in the app's terms, the modification of the libraries or the reverse engineering needed to debug such modifications.
- If you change FluidSynth or libsndfile, publish your changed source under the LGPL.

Distribution through an app store can raise its own questions under the LGPL, in particular on iOS, where users cannot easily replace a library inside a signed app. Decide for your own app whether you need advice on that.

This is not legal advice.
