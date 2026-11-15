import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:khuur_synth/khuur_synth.dart';

void main() => runApp(const MaterialApp(home: PianoPage()));

class PianoPage extends StatefulWidget {
  const PianoPage({super.key});

  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> {
  final _synth = Synth.open();
  LoadedSoundFont? _piano;
  Object? _error;
  var _reverb = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final synth = await _synth;
      final piano = await synth.load(const AssetSoundFont('assets/piano.sf2'));
      synth.select(channel: 0, font: piano, program: 0);
      setState(() => _piano = piano);
    } on SynthException catch (e) {
      setState(() => _error = e);
    }
  }

  /// Plays a C major chord, its third either equal-tempered or pure.
  Future<void> _chord({required bool pure}) async {
    final synth = await _synth;
    await synth.start();
    for (final (key, cents) in [(60, 0.0), (64, pure ? -13.7 : 0.0), (67, pure ? 2.0 : 0.0)]) {
      synth.noteOn(channel: 0, key: key, velocity: 90, cents: cents);
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    synth.allNotesOff();
    await synth.stop(ringOut: true);
  }

  Future<void> _setReverb(bool on) async {
    (await _synth).reverb = on ? const Reverb() : null;
    setState(() => _reverb = on);
  }

  @override
  void dispose() {
    unawaited(_synth.then((synth) => synth.close()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final piano = _piano;
    return Scaffold(
      appBar: AppBar(title: const Text('khuur_synth')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch ((piano, _error)) {
          (_, final Object error) => Text('$error'),
          (null, _) => const Center(child: CircularProgressIndicator()),
          (final LoadedSoundFont piano, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text('Presets: ${piano.presets.map((p) => '${p.bank}:${p.program} ${p.name}').join(', ')}'),
              FilledButton(onPressed: () => _chord(pure: false), child: const Text('C major, equal temperament')),
              FilledButton(onPressed: () => _chord(pure: true), child: const Text('C major, pure third and fifth')),
              SwitchListTile(title: const Text('Reverb'), value: _reverb, onChanged: _setReverb),
            ],
          ),
        },
      ),
    );
  }
}
