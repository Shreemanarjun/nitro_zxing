import 'package:nitro/nitro.dart';

part 'nitro_zxing.g.dart';

/// A barcode symbology zxing-cpp can read.
@HybridEnum()
enum ZxingFormat {
  qrCode,
  microQrCode,
  aztec,
  dataMatrix,
  pdf417,
  code128,
  code39,
  code93,
  codabar,
  ean13,
  ean8,
  upcA,
  upcE,
  itf,
}

/// How the pixels passed to a decode call are laid out.
@HybridEnum()
enum ZxingPixelFormat {
  /// 8-bit luminance, 1 byte per pixel (e.g. a YUV frame's Y plane).
  luma,

  /// 4 bytes per pixel, B G R A (nitro_camera's default frame format).
  bgra,

  /// 4 bytes per pixel, R G B A.
  rgba,

  /// 3 bytes per pixel, R G B.
  rgb,

  /// 3 bytes per pixel, B G R.
  bgr,
}

/// One decoded barcode.
@HybridRecord()
class ZxingResult {
  final String text;
  final ZxingFormat format;

  /// Corner points x0,y0 … x3,y3 in the input image's pixel space
  /// (top-left, top-right, bottom-right, bottom-left).
  final List<int> corners;

  const ZxingResult({
    required this.text,
    required this.format,
    required this.corners,
  });
}

/// zxing-cpp (C++) barcode decoding over FFI — the Dart/Flutter counterpart
/// of react-native-nitro-zxing. Calls are synchronous and thread-safe, so they
/// can run straight on a frame-processor isolate.
///
/// Use the `decode` / `decodeAll` extension methods; [readBarcodes] is the raw
/// bridge call they wrap.
@NitroModule(
  lib: 'nitro_zxing',
  ios: AppleNativeImpl.cpp,
  android: AndroidNativeImpl.cpp,
  linux: NativeImpl.cpp,
  macos: AppleNativeImpl.cpp,
  windows: NativeImpl.cpp,
)
abstract class NitroZxing extends HybridObject {
  static final NitroZxing instance = _NitroZxingImpl();

  /// Decodes up to [maxSymbols] barcodes (0 = no limit) of [formats] (empty =
  /// every format) from [pixels] laid out as [pixelFormat]. [rowStride] is in
  /// bytes and may exceed the row width (padded rows); 0 means unpadded.
  /// [live] enables the live-camera ladder: a plain scan every call, plus a
  /// rotation-tolerant scan on every 4th call that misses. The buffer is only
  /// read during the call.
  List<ZxingResult> readBarcodes(
    @zeroCopy Uint8List pixels,
    int width,
    int height,
    int rowStride,
    ZxingPixelFormat pixelFormat,
    List<ZxingFormat> formats,
    bool live,
    int maxSymbols,
  );
}
