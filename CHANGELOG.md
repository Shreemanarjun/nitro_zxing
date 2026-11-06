## 0.0.1 - 2026-11-04

Initial release.

### Added

* **Reading** — `NitroZxing.instance.decode(pixels, width:, height:, …)`
  returns the first barcode (or null), `decodeAll(…)` every barcode, each a
  `ZxingResult`. Named options: `rowStride`, `pixelFormat`, `formats` (a
  `Set<ZxingFormat>`, empty = all), `live`, `region`, `options`, and
  `maxSymbols` for `decodeAll`.
* **Pixel formats** — 8-bit luma (a YUV frame's Y plane), BGRA (nitro_camera's
  default frames), RGBA, ARGB, ABGR, RGB and BGR via `ZxingPixelFormat`.
* **Image files** — `decodeImage` / `decodeImageAll` read PNG, JPEG, BMP, GIF,
  TGA, PSD, HDR, PIC and PNM bytes (bundled stb_image).
* **Region of interest** — `region: (left:, top:, width:, height:)` searches a
  rectangle without copying; corners stay in full-image coordinates.
* **Rich results** — `bytes`, `contentType`, `orientation`, `isMirrored`,
  `isInverted`, `ecLevel` and `symbologyIdentifier` alongside `text`,
  `format` and `corners`; `bounds`, `topLeft` … `bottomLeft` helpers for
  overlays.
* **Reader options** — `ZxingReaderOptions`: `tryHarder`, `tryRotate`,
  `tryInvert`, `tryDownscale`, `isPure`, `binarizer` and `textMode`.
* **Writing** — `encode` renders the 13 `ZxingFormats.writable` formats to an
  8-bit luma `ZxingImage`; `encodePng` / `ZxingImage.toPng()` produce PNG
  bytes. `ZxingQrEcLevel` names the QR levels; other formats throw an
  `ArgumentError`. 1D codes without a height get 40 % of their width.
* **Async helpers** — `decodeAsync`, `decodeAllAsync`, `decodeImageAsync` and
  `decodeImageAllAsync` run on a background isolate.
* **Format groups** — `ZxingFormats.linear`, `.matrix`, `.retail`, `.dataBar`,
  `.writable`, `.all`.
* **19 symbologies** — QR, Micro QR, rMQR, Aztec, Data Matrix, PDF417,
  MaxiCode, Code 128/39/93, Codabar, EAN-13/8, UPC-A/E, ITF and GS1 DataBar
  (Omni, Expanded, Limited), as the `ZxingFormat` enum. UPC-A/E are reported
  as 13-digit GTINs, as zxing-cpp does.
* **Dart and Flutter, five platforms** — Android, iOS, macOS, Windows and Linux
  from one C++ source over nitro FFI. A nitrogen-generated build hook (native
  assets) compiles the library for `flutter build`, `dart run` and
  `dart build cli` alike; no JNI, no Swift, no platform channel, no setup.
  Building needs CMake on `PATH`. The library exports only nitro's bridge
  (zxing-cpp and stb symbols stay private).
* **Live-camera ladder** — `live: true` runs a cheap scan per frame plus a
  rotation-tolerant scan on every 4th miss.
* **Performance** — ~2 µs bridge overhead per call; a 1080p luma frame decodes
  in ~1.1 ms on an Apple M1 Pro (`example_dart/bin/benchmark.dart`). Native-
  backed buffers (a `NitroBuffer` view or nitro_camera's `attachDirect`
  frames) cross by pointer; a Dart-heap buffer is copied once.
