# khuur_synth example

Loads a piano SoundFont, lists its presets, and plays a C major chord either in equal temperament or with a pure third and fifth, with reverb on or off. All of it is in `lib/main.dart`.

`assets/piano.sf2` is the Grand Piano preset cut from GeneralUser GS 2.0.3 by S. Christian Collins. Its licence is in `assets/GeneralUser-GS-LICENSE.txt`.

## Run it

The synth plays only on iOS and Android, so run the example on a simulator, an emulator or a device. From this folder, run the following.

```bash
flutter run -d <device>
```

## The device test

The integration test loads the piano, measures the pitch of detuned notes from a render, plays through the device, rings out, and runs two synths at once.

```bash
flutter test integration_test/synth_test.dart -d <device>
```
