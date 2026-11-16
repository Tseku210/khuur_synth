import '../engine.dart';
import '../synth_exception.dart';

/// The engine where Dart has no `dart:ffi`, as on the web. It never opens.
abstract final class FluidEngine implements Engine {
  /// Throws `SynthUnavailable`.
  factory FluidEngine.open({required int channels, bool keepsInput = false}) =>
      throw const SynthUnavailable('khuur_synth does not run on the web.');
}
