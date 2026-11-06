# Nitro ZXing 🔍

[zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) barcode and QR **reading and writing** for **Dart and Flutter**, built on the **Nitro** FFI bridge — the counterpart of react-native-nitro-zxing. One C++ implementation serves **Android, iOS, macOS, Windows and Linux**: no JNI, no Swift, no platform channel, and no setup — a build hook compiles the native library for whatever you build.

[![Nitro](https://img.shields.io/badge/Powered%20by-Nitro-cyan.svg)](https://pub.dev/packages/nitro)
[![zxing-cpp](https://img.shields.io/badge/zxing--cpp-3.1.1-orange.svg)](https://github.com/zxing-cpp/zxing-cpp)
[![Dart](https://img.shields.io/badge/Dart%20%26%20Flutter-native%20assets-blue.svg)](https://dart.dev/tools/hooks)

## 🌟 Features

* **Dart and Flutter** — the same package works in Flutter apps and in plain Dart (`dart run`, `dart build cli`, servers).
* **Five platforms** — Android, iOS, macOS, Windows and Linux from one C++ source.
* **19 symbologies** — QR, Micro QR, rMQR, Aztec, Data Matrix, PDF417, MaxiCode, Code 128/39/93, Codabar, EAN-13/8, UPC-A/E, ITF and GS1 DataBar (Omni, Expanded, Limited), with ready-made groups (`ZxingFormats.linear`, `.matrix`, `.retail`, `.dataBar`).
* **Camera frames as they come** — 8-bit luma (a YUV frame's Y plane), BGRA (nitro_camera's default), RGBA, ARGB, ABGR, RGB or BGR, with padded rows.
* **Image files** — decode PNG, JPEG, BMP, GIF and more straight from their bytes.
* **Several codes per image**, a **region of interest** (no copy), and **rich results**: raw bytes, content type, orientation, mirrored/inverted flags, error-correction level, plus `bounds` and corner helpers for overlays.
* **Barcode generation** — render 13 formats (`ZxingFormats.writable`) to pixels or a PNG.
* **Fast** — ~2 µs bridge overhead per call; a 1080p camera frame decodes in ~1 ms ([numbers below](#-performance)).
* **Synchronous & thread-safe** — call it straight from a frame-processor isolate, or use the `…Async` variants.
* **Self-contained** — the native library exports only nitro's bridge; its zxing-cpp and stb code stay private, so another copy elsewhere in your app can't clash with them.

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
import 'dart:io';

import 'package:nitro_zxing/nitro_zxing.dart';

final zxing = NitroZxing.instance;

// A camera frame, e.g. in a nitro_camera CameraFrameProcessor handler —
// YUV frames (format 0) carry the luma plane, BGRA frames (format 1) colour:
final r = zxing.decode(
  frame.bytes,
  width: frame.width,
  height: frame.height,
  rowStride: frame.effectiveBytesPerRow,
  pixelFormat: frame.format == 1 ? ZxingPixelFormat.bgra : ZxingPixelFormat.luma,
  formats: {ZxingFormat.qrCode},
  live: true, // cheap scan per frame, rotation scan every 4th miss
);
if (r != null) print('${r.text} (${r.format.name}) at ${r.corners}');

// An image file:
final fromFile = zxing.decodeImage(File('ticket.png').readAsBytesSync());

// Generate a QR code as PNG bytes (Flutter: Image.memory(png)):
final png = zxing.encodePng('https://dart.dev', format: ZxingFormat.qrCode, width: 300, height: 300);
```

Decoding is synchronous. In a Flutter app run it off the UI isolate — in your camera's frame processor, or with `decodeAsync` / `decodeImageAsync`.

## 📖 Reading

### Raw pixels

```dart
ZxingResult? r = zxing.decode(pixels, width: w, height: h);   // first code, or null
List<ZxingResult> all = zxing.decodeAll(pixels, width: w, height: h);  // every code
```

| Parameter | Default | Meaning |
| :--- | :--- | :--- |
| `width`, `height` | required | Image size in pixels. |
| `rowStride` | `0` | Bytes per row (0 = unpadded); camera frames are often padded. |
| `pixelFormat` | `luma` | `luma` (1 byte/px), `bgra`, `rgba`, `argb`, `abgr` (4), `rgb`, `bgr` (3). Luma is fastest. |
| `formats` | `{}` (all) | Symbologies to look for, e.g. `{ZxingFormat.qrCode}` or `ZxingFormats.retail`. Fewer is faster. |
| `live` | `false` | Camera mode: a fast scan per call, plus a rotation-tolerant scan on every 4th miss. Off = thorough (rotation, inversion, downscaling). |
| `region` | `null` | `(left: , top: , width: , height: )` to search only that rectangle — no copy; corners stay in full-image coordinates. |
| `options` | defaults | `ZxingReaderOptions`, below. |
| `maxSymbols` | `0` (no limit) | `decodeAll` only. |

`pixels` is only read during the call.

### Image files

```dart
ZxingResult? r = zxing.decodeImage(fileBytes);         // PNG, JPEG, BMP, GIF, TGA, PSD, HDR, PIC, PNM
List<ZxingResult> all = zxing.decodeImageAll(fileBytes);
```

Same `formats`, `region` and `options` parameters (plus `maxSymbols` on `decodeImageAll`). Returns null / empty if the bytes aren't a readable image.

### Off the calling isolate

```dart
final r = await zxing.decodeAsync(pixels, width: w, height: h);
final all = await zxing.decodeAllAsync(pixels, width: w, height: h);
final f = await zxing.decodeImageAsync(fileBytes);
final fAll = await zxing.decodeImageAllAsync(fileBytes);
```

`decodeAsync` / `decodeAllAsync` take `decode` / `decodeAll`'s parameters except `live`; `decodeImageAsync` / `decodeImageAllAsync` take `decodeImage` / `decodeImageAll`'s. Each call runs on a short-lived isolate (`Isolate.run`, ~0.1 ms extra) and copies the bytes over — right for occasional decodes from Flutter's UI isolate. For a camera stream, decode in a long-lived frame-processor isolate instead.

### Reader options

```dart
zxing.decode(pixels, width: w, height: h, options: const ZxingReaderOptions(
  tryInvert: false,                        // skip light-on-dark codes
  isPure: true,                            // clean generated image: ~1.6× faster
  binarizer: ZxingBinarizer.globalHistogram,
  textMode: ZxingTextMode.hex,
));
```

| Option | Default | Meaning |
| :--- | :--- | :--- |
| `tryHarder`, `tryRotate`, `tryInvert`, `tryDownscale` | `!live` | Extra search passes: more time, more codes found. |
| `isPure` | `false` | The image is a clean, axis-aligned barcode with no background. |
| `binarizer` | `localAverage` | `localAverage`, `globalHistogram`, `fixedThreshold` (127), `boolCast` (already black/white). |
| `textMode` | `hri` | How `text` is rendered: `plain`, `eci`, `hri` (human-readable, e.g. GS1 `(01)…`), `escaped`, `hex`. |

### Results

| `ZxingResult` field | Type | Meaning |
| :--- | :--- | :--- |
| `text` | `String` | The content, rendered per `textMode`. |
| `format` | `ZxingFormat` | The symbology found. |
| `corners` | `List<int>` | `x0,y0 … x3,y3` (top-left, top-right, bottom-right, bottom-left) in the input's pixel space. For 1D codes they mark the scan line where the code was read, so the outline is (nearly) a line. |
| `bytes` | `Uint8List` | The raw content, e.g. a binary QR payload. |
| `contentType` | `ZxingContentType` | `text`, `binary`, `mixed`, `gs1`, `iso15434`, `unknownEci`. |
| `orientation` | `int` | Rotation in degrees, clockwise, in −180…180 (270° reads as `-90`). |
| `isMirrored`, `isInverted` | `bool` | Mirrored / light-on-dark code. |
| `ecLevel` | `String` | Error-correction level as zxing reports it: a letter for QR / rMQR (`"L"`, `"M"`, `"Q"`, `"H"`), a percentage for PDF417 / Aztec (e.g. `"58%"`), a mode digit for MaxiCode; empty if none. |
| `symbologyIdentifier` | `String` | ISO/IEC 15424 identifier, e.g. `"]Q1"`. |

Geometry helpers for drawing an overlay:

```dart
final (:left, :top, :width, :height) = r.bounds;  // axis-aligned box around the corners
final ({int x, int y}) tl = r.topLeft;           // also topRight, bottomRight, bottomLeft
```

UPC-A and UPC-E codes are reported as 13-digit GTINs, as zxing-cpp does: UPC-A gains a leading `0` (`036000291452` → `0036000291452`) and UPC-E expands to its EAN-13 form.

### Formats

`ZxingFormat`: `qrCode`, `microQrCode`, `rmqrCode`, `aztec`, `dataMatrix`, `pdf417`, `maxiCode`, `code128`, `code39`, `code93`, `codabar`, `ean13`, `ean8`, `upcA`, `upcE`, `itf`, `dataBar` (Omni, incl. Stacked), `dataBarExpanded` (incl. Expanded Stacked), `dataBarLimited`.

`ZxingFormats.linear` (1D), `.matrix` (2D), `.retail` (EAN/UPC), `.dataBar`, `.writable` (what `encode` accepts) and `.all`.

GS1 data (DataBar, GS1 QR, …) reads human-readable by default — `(01)04412345678909` — and as the raw digits with `textMode: ZxingTextMode.plain`.

## ✏️ Writing

```dart
ZxingImage img = zxing.encode('Hello', format: ZxingFormat.dataMatrix, width: 200, height: 200);
// img.width, img.height, img.pixels (8-bit luma, unpadded) — img.toPng() for a PNG file
Uint8List png = zxing.encodePng('https://dart.dev', format: ZxingFormat.qrCode, width: 300, height: 300);
```

| Parameter | Default | Meaning |
| :--- | :--- | :--- |
| `format` | required | One of `ZxingFormats.writable`: every format but Micro QR, rMQR, MaxiCode and DataBar (which zxing-cpp can read but not write). |
| `width`, `height` | `0` | Requested size in pixels; 0 = the smallest that fits. A hint: writers keep the symbol's aspect ratio. A 1D code with no `height` is drawn 40 % as tall as it is wide; a square 2D code given one side uses it for both. |
| `margin` | symbology default | Quiet zone in pixels. |
| `ecLevel` | default | One 0–8 scale, higher = more error correction: QR 0–2 → L, 3–4 → M, 5–6 → Q, 7–8 → H (default L); PDF417 its level 0–8; Aztec a minimum of level × 12.5 %. Ignored for other formats and outside 0–8. |

For QR, `ZxingQrEcLevel.low` / `.medium` / `.quartile` / `.high` name the four levels: `ecLevel: ZxingQrEcLevel.high`.

Throws an `ArgumentError` for a format outside `ZxingFormats.writable`, and an exception if the text can't be encoded in the format (e.g. letters in an EAN-13).

## 🖥️ Pure Dart (CLI, server)

Same API, nothing to set up — see [example_dart/](example_dart/):

```bash
dart run bin/main.dart
dart build cli -t bin/main.dart   # ships the library next to the binary
```

Use `dart build cli`, not `dart compile exe`: only `build` bundles the native library.

## ⚡ Performance

Per call, AOT-compiled on an Apple M1 Pro ([example_dart/bin/benchmark.dart](example_dart/bin/benchmark.dart)):

| Call | Time |
| :--- | ---: |
| Bridge round trip (empty 8×8 image) | 2 µs |
| QR, 256×256 luma, `live`, `formats: {qrCode}` | 77 µs |
| Same, all 19 formats | 90 µs |
| Same, BGRA pixels | 165 µs |
| 1080p luma frame, `live`, QR only | 1.1 ms |
| 1080p frame with a 256×256 `region` | 0.12 ms |
| `decodeImage`, 256×256 PNG | 95 µs |
| `encode` QR, 256×256 | 145 µs |
| `encodePng` QR, 256×256 | 0.4 ms |

Tips for camera scanning:

* **Pass luma (YUV) frames** when you can: about 2× faster than BGRA.
* **Narrow `formats`** to what you expect.
* **Use a `region`** for a scan window: 10× faster on a 1080p frame.
* **Keep `live: true`** on a camera stream.
* **Avoid the copy**: `pixels` cross by pointer when they are a native-backed view (a `NitroBuffer` view, or nitro_camera's `attachDirect` frames); a plain Dart-heap `Uint8List` is copied once per call.

## 📄 License

MIT — see [LICENSE](LICENSE). Bundled: zxing-cpp (Apache-2.0, [src/zxing-cpp/LICENSE](src/zxing-cpp/LICENSE)), stb_image / stb_image_write (public domain or MIT, [src/stb/](src/stb/)), and a few zxing-cpp test sample images (Apache-2.0, [test/samples/](test/samples/)).
