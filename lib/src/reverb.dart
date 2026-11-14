/// FluidSynth's reverb, in FluidSynth's own units.
///
/// `Reverb()` is FluidSynth's default sound.
final class Reverb {
  const Reverb({this.roomSize = 0.2, this.damping = 0, this.width = 0.5, this.level = 0.9});

  /// From 0 to 1. Near 1 the tail barely decays.
  final double roomSize;

  /// From 0 to 1.
  final double damping;

  /// From 0 to 100.
  final double width;

  /// From 0 to 1.
  final double level;

  @override
  bool operator ==(Object other) =>
      other is Reverb &&
      other.roomSize == roomSize &&
      other.damping == damping &&
      other.width == width &&
      other.level == level;

  @override
  int get hashCode => Object.hash(roomSize, damping, width, level);

  @override
  String toString() => 'Reverb(roomSize: $roomSize, damping: $damping, width: $width, level: $level)';
}
