/// Where a SoundFont comes from.
sealed class SoundFont {
  /// Lets the subclasses be constant.
  const SoundFont();
}

/// A SoundFont bundled as a Flutter asset, named by its asset key.
///
/// FluidSynth reads from a path, so the asset is copied to the app's
/// temporary folder the first time a process loads it.
final class AssetSoundFont extends SoundFont {
  /// The asset named [key], as in `pubspec.yaml`.
  const AssetSoundFont(this.key);

  /// The asset key, such as `assets/piano.sf2`.
  final String key;

  @override
  bool operator ==(Object other) => other is AssetSoundFont && other.key == key;

  @override
  int get hashCode => Object.hash(AssetSoundFont, key);

  @override
  String toString() => 'AssetSoundFont($key)';
}

/// A SoundFont file on the device, such as one the app downloaded.
final class FileSoundFont extends SoundFont {
  /// The file at [path].
  const FileSoundFont(this.path);

  /// The file's absolute path.
  final String path;

  @override
  bool operator ==(Object other) => other is FileSoundFont && other.path == path;

  @override
  int get hashCode => Object.hash(FileSoundFont, path);

  @override
  String toString() => 'FileSoundFont($path)';
}

/// One preset in a loaded SoundFont, as the file names it.
final class Preset {
  /// The preset at [bank] and [program], called [name].
  const Preset({required this.bank, required this.program, required this.name});

  /// From 0 to 16383. Bank 128 holds the drum kits in a General MIDI file.
  final int bank;

  /// From 0 to 127.
  final int program;

  /// The name the file gives the preset, which may be empty.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Preset && other.bank == bank && other.program == program && other.name == name;

  @override
  int get hashCode => Object.hash(bank, program, name);

  @override
  String toString() => 'Preset($bank:$program $name)';
}
