/// Which tuning calls a note needs before it is struck.
///
/// A channel gets a tuning on its first detuned note, and from then on only a
/// key whose cents change is retuned. A channel never detuned has no tuning.
final class KeyTuning {
  final _channels = <int, Map<int, double>>{};

  ({bool retune, bool activate}) prepare(int channel, int key, double cents) {
    final keys = _channels[channel];
    if (keys == null) {
      if (cents == 0) return (retune: false, activate: false);
      _channels[channel] = {key: cents};
      return (retune: true, activate: true);
    }
    if ((keys[key] ?? 0) == cents) return (retune: false, activate: false);
    keys[key] = cents;
    return (retune: true, activate: false);
  }
}
