# Nitro ZXing 🔍

[zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) barcode and QR decoding for **Dart and Flutter**, built on the **Nitro** FFI bridge — the counterpart of react-native-nitro-zxing. One C++ implementation serves **Android, iOS, macOS, Windows and Linux**: no JNI, no Swift, no platform channel, and no setup — a build hook compiles the native library for whatever you build.

[![Nitro](https://img.shields.io/badge/Powered%20by-Nitro-cyan.svg)](https://pub.dev/packages/nitro)
[![zxing-cpp](https://img.shields.io/badge/zxing--cpp-3.1.1-orange.svg)](https://github.com/zxing-cpp/zxing-cpp)
[![Dart](https://img.shields.io/badge/Dart%20%26%20Flutter-native%20assets-blue.svg)](https://dart.dev/tools/hooks)

## 🌟 Features

* **Dart and Flutter** — the same package works in Flutter apps and in plain Dart (`dart run`, `dart build cli`, servers).
* **Five platforms** — Android, iOS, macOS, Windows and Linux from one C++ source.
* **14 symbologies** — QR, Micro QR, Aztec, Data Matrix, PDF417, Code 128/39/93, Codabar, EAN-13/8, UPC-A/E and ITF.
* **Synchronous & thread-safe** — call it straight from a frame-processor isolate.
* **Zero-copy input** — native-backed buffers cross by pointer.
* **Live-camera ladder** — a cheap scan per frame, plus a rotation-tolerant scan on every 4th miss.
* **Corner points** — the code's quadrilateral in the input image's pixel space.

## 🚀 Installation

```bash
flutter pub add nitro_zxing   # Flutter
dart pub add nitro_zxing      # pure Dart
```

The native library is built by the package's [build hook](https://dart.dev/tools/hooks) on first build, so the build machine needs:

- **CMake** on `PATH` (for every target — Xcode doesn't ship it: `brew install cmake`)
- a C++ toolchain for the target: Xcode (iOS/macOS), the Android NDK (installed with Flutter's Android setup), Visual Studio (Windows), or a compiler plus `make` (Linux)

Tested with Flutter's default targets: Android **minSdk 24**, **iOS 15.0** and **macOS 12.0**. No permissions — pair it with a camera plugin such as [nitro_camera](https://github.com/Shreemanarjun/nitro_camera) for live scanning.

## ⏱️ Quick Start

```dart
import 'package:nitro_zxing/nitro_zxing.dart';

// e.g. inside a nitro_camera CameraFrameProcessor handler; with YUV frames
// (format 0) `frame.bytes` is the Y (luma) plane:
final r = NitroZxing.instance.decodeLuma(
  frame.bytes, frame.width, frame.height, frame.effectiveBytesPerRow,
  ZxingFormat.qrCode, true, // live: cheap scan per frame, rotation scan every 4th miss
);
if (r.text.isNotEmpty) print('${r.text} at ${r.corners}');
```

`decodeLuma` is synchronous, so in a Flutter app call it from a worker isolate, not the UI isolate.

### Pure Dart (CLI, server)

Same API, nothing to set up — see [example_dart/](example_dart/):

```bash
dart run bin/main.dart
dart build cli -t bin/main.dart   # ships the library next to the binary
```

Use `dart build cli`, not `dart compile exe`: only `build` bundles the native library.

## 🧭 API Reference

```dart
ZxingResult decodeLuma(
  Uint8List luma,  // 8-bit luminance (e.g. a YUV frame's Y plane); read only during the call
  int width,
  int height,
  int rowStride,   // may exceed width (padded rows)
  int formats,     // ZxingFormat bitmask
  bool live,       // enable the live-camera ladder
);
```

`ZxingResult`:

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `text` | `String` | Decoded text; empty when nothing was found. |
| `format` | `int` | The decoded `ZxingFormat` bit; 0 on a miss. |
| `corners` | `List<int>` | `x0,y0 … x3,y3` (top-left, top-right, bottom-right, bottom-left); empty on a miss. |

`ZxingFormat` bits OR together: `ZxingFormat.qrCode | ZxingFormat.ean13`, or `ZxingFormat.all`.

### Copies

`luma` crosses by pointer when it is a native-backed view (a `NitroBuffer` view, or nitro_camera's `attachDirect` frames); a plain Dart-heap `Uint8List` is copied once (~0.1 ms for 640×480).

## 📄 License

MIT — see [LICENSE](LICENSE). The vendored zxing-cpp is Apache-2.0 ([src/zxing-cpp/LICENSE](src/zxing-cpp/LICENSE)).
