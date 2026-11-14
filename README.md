# khuur_synth

Plays SoundFonts on iOS and Android with [FluidSynth](https://www.fluidsynth.org) 2.6.2, called from Dart through `dart:ffi`.

A `Synth` is one FluidSynth synthesizer with 256 MIDI channels. It loads SF2 files from assets or from disk, plays notes on any channel with any preset, can detune each note by cents, and sounds through the device or renders samples without it. The same synth sounds the same on both platforms, because both run FluidSynth.

## Install

```yaml
dependencies:
  khuur_synth: ^0.1.0
```

The plugin needs iOS 15 or later and Android API 24 or later. On iOS it uses Swift Package Manager and has no CocoaPods spec, so the app must have Swift Package Manager turned on, which is Flutter's default.

## Play a note

```dart
import 'package:khuur_synth/khuur_synth.dart';

final synth = await Synth.open();
final piano = await synth.load(const AssetSoundFont('assets/piano.sf2'));
synth.select(channel: 0, font: piano, program: 0);
await synth.start();

synth.noteOn(channel: 0, key: 60, velocity: 90);
await Future<void>.delayed(const Duration(seconds: 1));
synth.noteOff(channel: 0, key: 60);

await synth.stop(ringOut: true);
await synth.close();
```

`start` opens the device output and `stop` closes it. With `ringOut: true` the notes are released first and the output closes once the last one has faded, or after 10 seconds. Open the output while something plays and close it when the music ends, so the app holds no audio output while it is quiet.

## The API

- `Synth.open({reverb, chorus, gain, session})` makes a synth. `reverb` is a `Reverb` or null for none, `chorus` is on or off, and `gain` runs from 0 to 10, 0.2 by default as in FluidSynth. Each can be changed later through the setter of the same name.
- `load(source)` reads an `AssetSoundFont(key)` or a `FileSoundFont(path)` and answers a `LoadedSoundFont` with its `presets`. `unload(font)` frees it and silences the channels that played from it.
- `select(channel:, font:, program:, bank:)` sets what a channel plays. A preset the file lacks throws `PresetNotFound`.
- `noteOn(channel:, key:, velocity:, cents:)`, `noteOff`, `allNotesOff` and `allSoundsOff` play.
- `render(frames)` answers interleaved stereo float samples at 44.1 kHz while the synth is stopped, for tests and bounces.
- `Synth.silent()` runs every rule of a real synth and makes no sound. Its `onEvent` hears each call as a `SynthEvent`, from `package:khuur_synth/testing.dart`, so code that plays music can be tested on a host machine, where `Synth.open` throws `SynthUnavailable`.

Errors are the sealed `SynthException`: `SynthUnavailable`, `SoundFontLoadFailed`, `PresetNotFound` and `AudioOutputFailed`. Arguments out of range throw a `RangeError` at the call.

### Detuned notes

`cents` detunes one note, from -1200 to 1200, without touching the notes already sounding. Use it for just intonation, for instruments tuned away from 440 Hz, or for quarter tones. Each channel keeps its own tuning, so a detuned note on one channel never moves another channel's notes. On the iPhone simulator a note asked at -13.7 cents measured -13.85 cents, and every case tried was within 3 cents.

### Calls run in order

`load`, `unload`, `start`, `stop`, `render` and `close` return futures and run one at a time, in the order they were called. A note or setting called while one of them runs waits for it in Dart and then runs, so every call takes effect in the order it was made, and no call blocks the UI isolate on FluidSynth's lock. Loading a large file can stall the audio, so load before playing.

Each synth owns its own FluidSynth synthesizer and its own output. Two synths that load the same file share its samples, which FluidSynth keeps once per process.

## Platform notes

### iOS

- Only SF2 files load. The official FluidSynth framework is built without SF3 support.
- `start` sets the audio session as `session` says. `AudioSessionPolicy.playback`, the default, is `.playback` without mixing, so other apps' audio stops and the ring switch does not mute the synth. `playbackMixing` mixes with other apps. `manual` leaves the session to the app.
- FluidSynth's driver sets the session to `.playback` mixed with others whenever it opens. The plugin sets its policy again once the driver is open. With `manual`, set your own session again after `start` returns.
- An app that records, such as one that listens to the microphone, leaves the session in a record category. `start` moves it to playback, so set the record category again before you record.
- After an interruption ends or the media services reset, a started synth opens its output again by itself.

### Android

- SF2 files load. The Android release also links libsndfile with Vorbis, which FluidSynth needs for SF3, but SF3 has not been tried yet.
- Audio goes out through Oboe. The plugin does not request audio focus, so the app does that if it needs to.
- The plugin bundles `libc++_shared.so` through a small native library of its own, built by the app's NDK, so it merges with any other plugin's copy.
- The libraries are built for arm64-v8a, armeabi-v7a and x86_64, and every one is aligned for 16 KB pages.

## Size

The FluidSynth libraries and their dependencies add about 2.9 MB for arm64-v8a on Android, plus the NDK's `libc++_shared.so` when the app has no copy yet, and about 2.6 MB on iOS. SoundFonts are the app's own and add their own size.

## The bundled binaries

The plugin ships the official FluidSynth 2.6.2 release binaries, unmodified apart from removed debug symbols. `tool/vendor_fluidsynth.sh` fetches the two release zips from [the release page](https://github.com/FluidSynth/fluidsynth/releases/tag/v2.6.2), checks each against a pinned SHA-256, strips the Android libraries, and checks their dependencies and alignment. Run it to update or to reproduce the binaries. `tool/ffigen.yaml` generates the Dart bindings from the headers it copies.

## Licences

The plugin's own code is MIT. FluidSynth and libsndfile are under the GNU Lesser General Public License 2.1 or later, and the other bundled libraries are under Apache-2.0 and BSD-3-Clause. `LICENSE` holds every text.

FluidSynth is linked dynamically on both platforms, as a shared library on Android and as a dynamic framework on iOS. Its source is at https://github.com/FluidSynth/fluidsynth, tag `v2.6.2`. An app that ships this plugin should name FluidSynth and its licence in its own licence notices. On Flutter, `LicenseRegistry` is one place to do that.

This is not legal advice.
