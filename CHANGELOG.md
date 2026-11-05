## 0.0.1 - 2026-11-04

Initial release.

### Added

* **zxing-cpp 3.1.1 decoding** — `NitroZxing.decodeLuma(luma, width, height,
  rowStride, formats, live)` decodes an 8-bit luminance image (e.g. a YUV
  frame's Y plane) and returns a `ZxingResult` with the text, symbology and
  corner points.
* **14 symbologies** — QR, Micro QR, Aztec, Data Matrix, PDF417, Code 128/39/93,
  Codabar, EAN-13/8, UPC-A/E and ITF, selected with a `ZxingFormat` bitmask.
* **Dart and Flutter, five platforms** — Android, iOS, macOS, Windows and Linux
  from one C++ source over nitro FFI. A nitrogen-generated build hook (native
  assets) compiles the library for `flutter build`, `dart run` and
  `dart build cli` alike; no JNI, no Swift, no platform channel, no setup.
  Building needs CMake on `PATH`.
* **Live-camera ladder** — `live: true` runs a cheap scan per frame plus a
  rotation-tolerant scan on every 4th miss.
* **Zero-copy input** — a native-backed `Uint8List` (a `NitroBuffer` view or
  nitro_camera's `attachDirect` frames) crosses by pointer; a Dart-heap buffer
  is copied once. Synchronous and thread-safe, so it runs straight on a
  frame-processor isolate.
