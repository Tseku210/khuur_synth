/// Plays SoundFonts on iOS and Android through FluidSynth.
///
/// Open a [Synth], load a SoundFont, pick a preset for a channel, open the
/// device output, and play notes.
///
/// ```dart
/// final synth = await Synth.open();
/// final piano = await synth.load(const AssetSoundFont('assets/piano.sf2'));
/// synth.select(channel: 0, font: piano, program: 0);
/// await synth.start();
///
/// synth.noteOn(channel: 0, key: 60, velocity: 90);
/// await Future<void>.delayed(const Duration(seconds: 1));
/// synth.noteOff(channel: 0, key: 60);
///
/// await synth.stop(ringOut: true);
/// await synth.close();
/// ```
///
/// [Synth.open] throws [SynthUnavailable] on macOS, Windows and Linux,
/// including in `flutter test` on a host machine. Tests use [Synth.silent],
/// whose events are in `package:khuur_synth/testing.dart`. On the web the
/// package compiles, and [Synth.open] throws [SynthUnavailable] there too.
library;

export 'src/audio_session.dart' show AudioSessionPolicy;
export 'src/reverb.dart';
export 'src/sound_font.dart';
export 'src/synth.dart' show LoadedSoundFont, Synth;
export 'src/synth_event.dart' show SynthEvent;
export 'src/synth_exception.dart';
