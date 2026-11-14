cmake_minimum_required(VERSION 3.10)
project(khuur_synth LANGUAGES CXX)

# Exists only so the app packages libc++_shared.so; see android/build.gradle.kts.
add_library(khuur_synth_stl SHARED stl.cpp)
