## 0.0.1 - 2026-11-04

Initial release.

### Added

* **zxing-cpp 3.1.1 decoding** — `NitroZxing.decodeLuma(luma, width, height,
  rowStride, formats, live)` decodes an 8-bit luminance image (e.g. a YUV
  frame's Y plane) and returns a `ZxingResult` with the text, symbology and
  corner points.
* **14 symbologies** — QR, Micro QR, Aztec, Data Matrix, PDF417, Code 128/39/93,
  Codabar, EAN-13/8, UPC-A/E and ITF, selected with a `ZxingFormat` bitmask.
* **Live-camera ladder** — `live: true` runs a cheap scan per frame plus a
  rotation-tolerant scan on every 4th miss.
* **Zero-copy input** — a native-backed `Uint8List` (a `NitroBuffer` view or
  nitro_camera's `attachDirect` frames) crosses by pointer; a Dart-heap buffer
  is copied once.
* **C++ only** on Android and iOS over nitro FFI — no JNI, no Swift, no
  platform channel. Synchronous and thread-safe, so it runs straight on a
  frame-processor isolate.
