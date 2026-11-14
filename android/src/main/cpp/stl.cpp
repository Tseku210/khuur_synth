#include <string>

extern "C" __attribute__((visibility("default"))) int khuur_synth_stl_size() {
  return static_cast<int>(std::string("khuur_synth").size());
}
