/// Where a SoundFont comes from.
sealed class SoundFont {
  const SoundFont();
}

/// A SoundFont bundled as a Flutter asset, named by its asset key.
///
/// FluidSynth reads from a path, so the asset is copied to the app's
/// temporary folder the first time a process loads it.
final class AssetSoundFont extends SoundFont {
  const AssetSoundFont(this.key);

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
  const FileSoundFont(this.path);

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
  const Preset({required this.bank, required this.program, required this.name});

  final int bank;
  final int program;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Preset && other.bank == bank && other.program == program && other.name == name;

  @override
  int get hashCode => Object.hash(bank, program, name);

  @override
  String toString() => 'Preset($bank:$program $name)';
}
