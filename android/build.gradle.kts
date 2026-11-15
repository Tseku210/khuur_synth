group = "mn.morinkhugur.khuur_synth"

plugins {
    id("com.android.library")
}

android {
    namespace = "mn.morinkhugur.khuur_synth"

    compileSdk = 36

    defaultConfig {
        minSdk = 24

        // FluidSynth and Oboe link the NDK's libc++_shared.so, which an app
        // packages only when one of its native builds asks for it. This tiny
        // library asks, so the app's own NDK supplies it and it merges with
        // other plugins' copies.
        externalNativeBuild {
            cmake {
                arguments("-DANDROID_STL=c++_shared")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
}
