#!/usr/bin/env bash
# Copies FluidSynth's official release binaries into the plugin.
#
#   tool/vendor_fluidsynth.sh [DIR]
#
# DIR holds the two release zips named below. Without DIR the zips are
# downloaded from the release page into a temporary folder. Either way each
# zip must match its pinned SHA-256 before anything is copied.
#
# Android: keeps arm64-v8a, armeabi-v7a and x86_64, drops x86, the asset
# loader and libvorbisfile (nothing links it), strips every library with the
# NDK's llvm-strip, and checks that each NEEDED entry is either vendored or
# an Android system library, and that every LOAD segment is 16 KB aligned.
# iOS: copies FluidSynth.xcframework without its dSYMs.
# Headers go to third_party/fluidsynth/include.
set -euo pipefail

VERSION=2.6.2
ANDROID_ZIP=fluidsynth-v$VERSION-android24.zip
ANDROID_SHA=f29d1fe9c46c8528c65d22b2bfcd15997960f908370531a5a9427a73ab9e5313
IOS_ZIP=fluidsynth-v$VERSION-iOS.zip
IOS_SHA=ba817b7ad1ed81874d06251f6b2cbd20ec8707ebd12e8a841fa97432afa522ed
RELEASE=https://github.com/FluidSynth/fluidsynth/releases/download/v$VERSION

ABIS=(arm64-v8a armeabi-v7a x86_64)
LIBS=(libfluidsynth libsndfile liboboe libFLAC libogg libopus libvorbis libvorbisenc)
SYSTEM_LIBS=" libc.so libm.so libdl.so liblog.so libandroid.so libOpenSLES.so libaaudio.so libc++_shared.so "

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ndk_bin() {
  local sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
  local ndk=${ANDROID_NDK_HOME:-$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1)}
  local bin
  bin=$(ls -d "$ndk"/toolchains/llvm/prebuilt/*/bin 2>/dev/null | head -1)
  [[ -x $bin/llvm-strip && -x $bin/llvm-readelf ]] || { echo "No NDK found; set ANDROID_NDK_HOME." >&2; exit 1; }
  echo "$bin"
}

fetch() {
  local name=$1 sha=$2 dir=${3:-}
  local zip=$WORK/$name
  if [[ -n $dir ]]; then
    cp "$dir/$name" "$zip"
  else
    curl -fL --retry 3 -o "$zip" "$RELEASE/$name"
  fi
  local got
  got=$(shasum -a 256 "$zip" | cut -d' ' -f1)
  [[ $got == "$sha" ]] || { echo "$name: SHA-256 is $got, expected $sha" >&2; exit 1; }
  mkdir -p "$WORK/${name%.zip}"
  unzip -q "$zip" -d "$WORK/${name%.zip}"
}

vendor_android() {
  local bin=$1 src=$WORK/${ANDROID_ZIP%.zip}
  local out=$ROOT/android/src/main/jniLibs
  rm -rf "$out"
  for abi in "${ABIS[@]}"; do
    mkdir -p "$out/$abi"
    local vendored=" "
    for lib in "${LIBS[@]}"; do vendored+="$lib.so "; done
    for lib in "${LIBS[@]}"; do
      "$bin/llvm-strip" --strip-unneeded -o "$out/$abi/$lib.so" "$src/lib/$abi/$lib.so"
      while read -r needed; do
        [[ $vendored == *" $needed "* || $SYSTEM_LIBS == *" $needed "* ]] ||
          { echo "$abi/$lib.so needs $needed, which is neither vendored nor a system library" >&2; exit 1; }
      done < <("$bin/llvm-readelf" -d "$out/$abi/$lib.so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
      while read -r align; do
        (( align >= 0x4000 )) || { echo "$abi/$lib.so has a LOAD segment aligned to $align, under 16 KB" >&2; exit 1; }
      done < <("$bin/llvm-readelf" -lW "$out/$abi/$lib.so" | awk '$1 == "LOAD" { print $NF }')
    done
  done
  rm -rf "$ROOT/third_party/fluidsynth/include"
  mkdir -p "$ROOT/third_party/fluidsynth"
  cp -R "$src/include" "$ROOT/third_party/fluidsynth/include"
}

vendor_ios() {
  local src=$WORK/${IOS_ZIP%.zip}/fluidsynth-v$VERSION-iOS/FluidSynth.xcframework
  local out=$ROOT/ios/khuur_synth/FluidSynth.xcframework
  rm -rf "$out"
  cp -R "$src" "$out"
  find "$out" -name dSYMs -type d -prune -exec rm -rf {} +
  plutil -remove AvailableLibraries.0.DebugSymbolsPath "$out/Info.plist" 2>/dev/null || true
  plutil -remove AvailableLibraries.1.DebugSymbolsPath "$out/Info.plist" 2>/dev/null || true
}

BIN=$(ndk_bin)
fetch "$ANDROID_ZIP" "$ANDROID_SHA" "${1:-}"
fetch "$IOS_ZIP" "$IOS_SHA" "${1:-}"
vendor_android "$BIN"
vendor_ios
echo "$VERSION" > "$ROOT/third_party/fluidsynth/VERSION"
du -sh "$ROOT/android/src/main/jniLibs"/* "$ROOT/ios/khuur_synth/FluidSynth.xcframework"
