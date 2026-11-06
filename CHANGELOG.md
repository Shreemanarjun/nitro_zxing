## 0.0.1 - 2026-11-04

Initial release: zxing-cpp 3.1.1 over nitro FFI for Dart and Flutter on
Android, iOS, macOS, Windows and Linux (build hook; needs CMake).

* Read 19 symbologies from raw pixels (luma, BGRA, RGBA, ARGB, ABGR, RGB, BGR)
  or image files: `decode`, `decodeAll`, `decodeImage`, plus `…Async` variants.
* Live-camera mode, region of interest, reader options with presets, and rich
  results with overlay helpers (`bounds`, `center`, `scale`).
* Write 13 formats to pixels or PNG: `encode`, `encodePng`.
