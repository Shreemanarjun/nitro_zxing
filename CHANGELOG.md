## 0.0.1 - 2026-11-04

Initial release.

### Added

* **Reading** — `NitroZxing.instance.decode(pixels, width:, height:, …)`
  returns the first barcode (or null), `decodeAll(…)` every barcode, each a
  `ZxingResult`. Named options: `rowStride`, `pixelFormat`, `formats` (a
  `Set<ZxingFormat>`, empty = all), `live`, `region`, `options`, and
  `maxSymbols` for `decodeAll`.
* **Pixel formats** — 8-bit luma (a YUV frame's Y plane), BGRA (nitro_camera's
  default frames), RGBA, RGB and BGR via `ZxingPixelFormat`.
* **Image files** — `decodeImage` / `decodeImageAll` read PNG, JPEG, BMP, GIF,
  TGA, PSD, HDR, PIC and PNM bytes (bundled stb_image).
* **Region of interest** — `region: (left:, top:, width:, height:)` searches a
  rectangle without copying; corners stay in full-image coordinates.
* **Rich results** — `bytes`, `contentType`, `orientation`, `isMirrored`,
  `isInverted`, `ecLevel` and `symbologyIdentifier` alongside `text`,
  `format` and `corners`.
* **Reader options** — `ZxingReaderOptions`: `tryHarder`, `tryRotate`,
  `tryInvert`, `tryDownscale`, `isPure`, `binarizer` and `textMode`.
* **Writing** — `encode` renders any format except Micro QR to an 8-bit luma
  `ZxingImage`; `encodePng` / `ZxingImage.toPng()` produce PNG bytes.
* **Async helpers** — `decodeAsync` / `decodeImageAsync` run on a background
  isolate.
* **Format groups** — `ZxingFormats.linear`, `.matrix`, `.retail`, `.all`.
* **14 symbologies** — QR, Micro QR, Aztec, Data Matrix, PDF417, Code 128/39/93,
  Codabar, EAN-13/8, UPC-A/E and ITF, as the `ZxingFormat` enum. UPC-A/E are
  reported as 13-digit GTINs, as zxing-cpp does.
* **Dart and Flutter, five platforms** — Android, iOS, macOS, Windows and Linux
  from one C++ source over nitro FFI. A nitrogen-generated build hook (native
  assets) compiles the library for `flutter build`, `dart run` and
  `dart build cli` alike; no JNI, no Swift, no platform channel, no setup.
  Building needs CMake on `PATH`.
* **Live-camera ladder** — `live: true` runs a cheap scan per frame plus a
  rotation-tolerant scan on every 4th miss.
* **Performance** — ~2 µs bridge overhead per call; a 1080p luma frame decodes
  in ~1.1 ms on an Apple M1 Pro (`example_dart/bin/benchmark.dart`). Native-
  backed buffers (a `NitroBuffer` view or nitro_camera's `attachDirect`
  frames) cross by pointer; a Dart-heap buffer is copied once.
