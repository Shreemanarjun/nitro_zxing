# Nitro ZXing 🔍

[zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) barcode and QR decoding for Flutter, built on the **Nitro** FFI bridge — the Flutter counterpart of react-native-nitro-zxing. One C++ implementation serves **Android, iOS, macOS, Windows and Linux** over FFI, and **web** as WebAssembly: no JNI, no Swift, no platform channel.

[![Nitro](https://img.shields.io/badge/Powered%20by-Nitro-cyan.svg)](https://pub.dev/packages/nitro)
[![zxing-cpp](https://img.shields.io/badge/zxing--cpp-3.1.1-orange.svg)](https://github.com/zxing-cpp/zxing-cpp)
[![Flutter](https://img.shields.io/badge/Flutter-3.3+-blue.svg)](https://flutter.dev)

## 🌟 Features

* **Six platforms** — Android, iOS, macOS, Windows, Linux and web (WASM) from one C++ source.
* **14 symbologies** — QR, Micro QR, Aztec, Data Matrix, PDF417, Code 128/39/93, Codabar, EAN-13/8, UPC-A/E and ITF.
* **Synchronous & thread-safe** — call it straight from a frame-processor isolate.
* **Zero-copy input** — native-backed buffers cross by pointer.
* **Live-camera ladder** — a cheap scan per frame, plus a rotation-tolerant scan on every 4th miss.
* **Corner points** — the code's quadrilateral in the input image's pixel space.

## 🚀 Installation

```yaml
dependencies:
  nitro_zxing: ^0.0.1
```

Or from the terminal:

```bash
flutter pub add nitro_zxing
```

Requires Android **minSdk 24**, **iOS 13.0+** and **macOS 10.15+**. No permissions — pair it with a camera plugin such as [nitro_camera](https://github.com/Shreemanarjun/nitro_camera) for live scanning.

## ⏱️ Quick Start

```dart
import 'package:nitro_zxing/nitro_zxing.dart';

// e.g. inside a nitro_camera CameraFrameProcessor handler (YUV frame → Y plane):
final r = NitroZxing.instance.decodeLuma(
  frame.bytes, frame.width, frame.height, frame.effectiveBytesPerRow,
  ZxingFormat.qrCode, true, // live: cheap scan per frame, rotation scan every 4th miss
);
if (r.text.isNotEmpty) print('${r.text} at ${r.corners}');
```

`decodeLuma` is synchronous, so call it from a worker isolate, not the UI isolate.

### Web

The WASM module ships in the package. Load it once before the first call (a no-op on other platforms):

```dart
await ensureNitroZxingReady();
```

On web, `luma` is copied into WASM memory on each call, and calls run on the browser's main thread.

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

## 🛠️ Development

- `lib/src/nitro_zxing.native.dart` — the nitro spec; `nitrogen generate && nitrogen link` after edits.
- `src/HybridNitroZxing.cpp` — the decoder (implements the generated `HybridNitroZxing`).
- `src/zxing-cpp/` — vendored zxing-cpp 3.1.1 core (Apache-2.0), readers only.
- iOS: `ios/nitro_zxing/Package.swift` builds `ZXingCore` from a symlink to the vendored sources; `Sources/ZXingCoreConfig/Version.h` stands in for the CMake-generated header.
- `windows/`, `linux/` — CMake entry points into the shared `src/CMakeLists.txt` (zxing included).
- macOS: `macos/nitro_zxing/Package.swift`, same layout as iOS.
- Web: `emcmake cmake -S src -B build/web -DCMAKE_BUILD_TYPE=Release && cmake --build build/web` writes `assets/web/nitro_zxing.{js,wasm}`. Use this, not `web/build_web.sh`: `nitrogen link` regenerates that script without the zxing sources.
- Don't run `nitrogen clean`: it deletes every `Hybrid*.cpp`, including the hand-written `src/HybridNitroZxing.cpp` and zxing's `HybridBinarizer.cpp`.

### Tests

- `test/native/decode_check.cpp` — host decode check (instructions in its header).
- `test/nitro_zxing_web_test.dart` — WASM decode in Chrome: `flutter test --platform chrome test/nitro_zxing_web_test.dart`.
- `example/integration_test/decode_test.dart` — on-device decode: `cd example && flutter test integration_test -d <device>`.

## 📄 License

MIT — see [LICENSE](LICENSE). The vendored zxing-cpp is Apache-2.0 ([src/zxing-cpp/LICENSE](src/zxing-cpp/LICENSE)).
