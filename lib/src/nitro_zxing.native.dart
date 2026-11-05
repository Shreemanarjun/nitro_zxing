import 'package:nitro/nitro.dart';

import 'nitro_zxing.platform.g.dart';

part 'nitro_zxing.g.dart';

/// One decode result. [text] is empty when nothing was found.
@HybridRecord()
class ZxingResult {
  final String text;

  /// The decoded symbology as a [ZxingFormat] bit (0 when nothing was found).
  final int format;

  /// Corner points x0,y0 … x3,y3 in the input image's pixel space
  /// (top-left, top-right, bottom-right, bottom-left); empty on a miss.
  final List<int> corners;

  const ZxingResult({
    required this.text,
    required this.format,
    required this.corners,
  });
}

/// zxing-cpp (C++) barcode decoding over FFI — the Flutter counterpart of
/// react-native-nitro-zxing. Calls are synchronous and thread-safe, so they
/// can run straight on a frame-processor isolate.
@NitroModule(
  lib: 'nitro_zxing',
  ios: AppleNativeImpl.cpp,
  android: AndroidNativeImpl.cpp,
  linux: NativeImpl.cpp,
  macos: AppleNativeImpl.cpp,
  windows: NativeImpl.cpp,
  web: WebNativeImpl.wasm,
)
abstract class NitroZxing extends HybridObject {
  /// On web, await `ensureNitroZxingReady()` before first use.
  static final NitroZxing instance = createNitroZxingInstance();

  /// Decodes an 8-bit luminance image (e.g. a YUV frame's Y plane).
  /// [rowStride] may exceed [width] (padded rows). [formats] is a bitmask of
  /// [ZxingFormat] values. [live] enables the live-camera ladder: a plain scan
  /// every call, plus a rotation-tolerant scan on every 4th call that misses.
  /// The buffer is only read during the call.
  ZxingResult decodeLuma(
    @zeroCopy Uint8List luma,
    int width,
    int height,
    int rowStride,
    int formats,
    bool live,
  );
}
