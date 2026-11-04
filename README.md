# nitro_zxing

[zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) barcode decoding for Flutter over
[nitro](https://pub.dev/packages/nitro) FFI — the Flutter counterpart of
react-native-nitro-zxing. The implementation is C++ only (`AndroidNativeImpl.cpp` /
`AppleNativeImpl.cpp`): no JNI, no Swift, no platform channel.

```dart
import 'package:nitro_zxing/nitro_zxing.dart';

// e.g. inside a nitro_camera CameraFrameProcessor handler (YUV frame → Y plane):
final r = NitroZxing.instance.decodeLuma(
  frame.bytes, frame.width, frame.height, frame.effectiveBytesPerRow,
  ZxingFormat.qrCode, true, // live: cheap scan per frame, rotation scan every 4th miss
);
if (r.text.isNotEmpty) print('${r.text} at ${r.corners}');
```

`decodeLuma` is synchronous and thread-safe, so call it from a worker isolate, not the UI isolate.

## Layout

- `lib/src/nitro_zxing.native.dart` — the nitro spec; `nitrogen generate && nitrogen link` after edits.
- `src/HybridNitroZxing.cpp` — the decoder (implements the generated `HybridNitroZxing`).
- `src/zxing-cpp/` — vendored zxing-cpp 3.1.1 core (Apache-2.0), readers only on Android.
- iOS: `ios/nitro_zxing/Package.swift` builds `ZXingCore` from a symlink to the vendored
  sources; `Sources/ZXingCoreConfig/Version.h` stands in for the CMake-generated header.
- `test/native/decode_check.cpp` — host decode check (instructions in its header).

## Copies

`luma` crosses by pointer when it is a native-backed view (a `NitroBuffer` view, or
nitro_camera's `attachDirect` frames); a plain Dart-heap `Uint8List` is copied once
(~0.1 ms for 640×480).
