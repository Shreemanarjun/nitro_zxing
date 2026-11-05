# syntax=docker/dockerfile:1
#
# Linux check on the standalone Dart SDK (no Flutter):
#  1. the C++ decode check against libnitro_zxing.so built from src/CMakeLists.txt;
#  2. the pure-Dart test and example_dart (`dart build cli`): the package's
#     build hook compiles and bundles the library itself, no manual step.
# The build fails if any check does.
#
#   docker build -t nitro-zxing-linux .
#   docker build --platform linux/amd64 --build-arg JOBS=2 .   # x86_64 under emulation:
#     fewer jobs, or qemu can crash gcc (internal compiler error)
# make: the hook runs cmake with its default (Unix Makefiles) generator.
FROM dart:stable
RUN apt-get update && apt-get install -y --no-install-recommends cmake make ninja-build g++ \
 && rm -rf /var/lib/apt/lists/*
ARG JOBS
ENV CMAKE_BUILD_PARALLEL_LEVEL=${JOBS}
WORKDIR /w
COPY . .
RUN cmake -S src -B build/lib -G Ninja -DCMAKE_BUILD_TYPE=Release \
 && cmake --build build/lib \
 && g++ -std=c++20 -Ilib/src/generated/cpp -Isrc -Isrc/native test/native/decode_check.cpp \
      -Lbuild/lib -lnitro_zxing -Wl,-rpath,/w/build/lib -o build/decode_check \
 && build/decode_check test/native/qr_margelo_256_stride272.luma
RUN dart pub get && dart test test/nitro_zxing_vm_test.dart
RUN cd example_dart && dart pub get \
 && dart build cli -t bin/main.dart -o /w/build/cli \
 && /w/build/cli/bundle/bin/main /w/test/native/qr_margelo_256_stride272.luma \
    | tee /dev/stderr | grep -q '^https://margelo.com '
