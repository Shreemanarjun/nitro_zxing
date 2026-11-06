import 'package:nitro/nitro.dart';

part 'nitro_zxing.g.dart';

/// A barcode symbology zxing-cpp can read. All but [microQrCode], [rmqrCode],
/// [maxiCode] and the DataBar formats can also be written.
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

  /// Rectangular Micro QR (rMQR).
  rmqrCode,

  /// MaxiCode (parcel logistics).
  maxiCode,

  /// GS1 DataBar Omnidirectional, including the Stacked variants.
  dataBar,

  /// GS1 DataBar Expanded, including Expanded Stacked.
  dataBarExpanded,

  /// GS1 DataBar Limited.
  dataBarLimited,
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

  /// 4 bytes per pixel, A R G B.
  argb,

  /// 4 bytes per pixel, A B G R.
  abgr,
}

/// What kind of data a barcode holds.
@HybridEnum()
enum ZxingContentType { text, binary, mixed, gs1, iso15434, unknownEci }

/// How pixels are turned into black/white before decoding.
@HybridEnum()
enum ZxingBinarizer {
  /// Local average for 2D codes, histogram for 1D (default; best overall).
  localAverage,

  /// Valley between the two largest histogram peaks.
  globalHistogram,

  /// Fixed threshold at 127.
  fixedThreshold,

  /// Any non-zero byte is white; fastest, for already-binarized input.
  boolCast,
}

/// How [ZxingResult.text] is rendered from the raw bytes.
@HybridEnum()
enum ZxingTextMode {
  /// Bytes transcoded using ECI info or a guessed character set.
  plain,

  /// Standard ECI protocol content, every ECI segment transcoded.
  eci,

  /// Human-readable interpretation, e.g. GS1 with `(01)` style brackets (default).
  hri,

  /// Non-graphical characters escaped, e.g. ASCII 29 as `<GS>`.
  escaped,

  /// The bytes as a hex string.
  hex,
}

/// Reader settings for one decode call (built by the `decode*` extension
/// methods from their named parameters).
@HybridRecord()
class ZxingReadOptions {
  /// Symbologies to look for; empty = every [ZxingFormat].
  final List<ZxingFormat> formats;
  final bool tryHarder;
  final bool tryRotate;
  final bool tryInvert;
  final bool tryDownscale;

  /// The image is a clean, axis-aligned barcode with no background.
  final bool isPure;
  final ZxingBinarizer binarizer;
  final ZxingTextMode textMode;

  /// 0 = no limit.
  final int maxSymbols;

  /// Live-camera ladder: retry with rotation on every 4th call that misses.
  final bool live;

  /// Region of interest in pixels; [regionWidth]/[regionHeight] 0 = whole image.
  final int regionLeft;
  final int regionTop;
  final int regionWidth;
  final int regionHeight;

  const ZxingReadOptions({
    required this.formats,
    required this.tryHarder,
    required this.tryRotate,
    required this.tryInvert,
    required this.tryDownscale,
    required this.isPure,
    required this.binarizer,
    required this.textMode,
    required this.maxSymbols,
    required this.live,
    required this.regionLeft,
    required this.regionTop,
    required this.regionWidth,
    required this.regionHeight,
  });
}

/// One decoded barcode.
@HybridRecord()
class ZxingResult {
  /// The content as text, rendered per the requested [ZxingTextMode].
  final String text;
  final ZxingFormat format;

  /// Corner points x0,y0 … x3,y3 in the input image's pixel space
  /// (top-left, top-right, bottom-right, bottom-left).
  final List<int> corners;

  /// The raw content bytes (e.g. a binary QR payload).
  final Uint8List bytes;
  final ZxingContentType contentType;

  /// Rotation of the barcode in degrees, clockwise, in -180…180 (a code
  /// turned 270° clockwise reads as -90).
  final int orientation;
  final bool isMirrored;

  /// Light-on-dark (inverted) barcode.
  final bool isInverted;

  /// Error-correction level as zxing reports it: a letter for QR ("L", "M",
  /// "Q", "H"), a percentage for PDF417 / Aztec (e.g. "58%"); empty if the
  /// symbology has none.
  final String ecLevel;

  /// ISO/IEC 15424 symbology identifier, e.g. "]Q1".
  final String symbologyIdentifier;

  const ZxingResult({
    required this.text,
    required this.format,
    required this.corners,
    required this.bytes,
    required this.contentType,
    required this.orientation,
    required this.isMirrored,
    required this.isInverted,
    required this.ecLevel,
    required this.symbologyIdentifier,
  });
}

/// A generated barcode image: 8-bit luma, [width]×[height], unpadded rows.
@HybridRecord()
class ZxingImage {
  final int width;
  final int height;
  final Uint8List pixels;

  const ZxingImage({
    required this.width,
    required this.height,
    required this.pixels,
  });
}

/// zxing-cpp (C++) barcode reading and writing over FFI — the Dart/Flutter
/// counterpart of react-native-nitro-zxing. Calls are synchronous and
/// thread-safe, so they can run straight on a frame-processor isolate.
///
/// Use the extension methods in `package:nitro_zxing/nitro_zxing.dart`
/// (`decode`, `decodeAll`, `decodeImage`, `encode`, …); the methods here are
/// the raw bridge calls they wrap.
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

  /// Decodes barcodes from raw [pixels] laid out as [pixelFormat].
  /// [rowStride] is in bytes (0 = unpadded). The buffer is only read during
  /// the call.
  List<ZxingResult> readBarcodes(
    @zeroCopy Uint8List pixels,
    int width,
    int height,
    int rowStride,
    ZxingPixelFormat pixelFormat,
    ZxingReadOptions options,
  );

  /// Decodes barcodes from an encoded image file (PNG, JPEG, BMP, GIF, TGA,
  /// PSD, HDR, PIC, PNM). Returns an empty list if it can't be decoded.
  List<ZxingResult> readBarcodesFromImage(
    Uint8List encoded,
    ZxingReadOptions options,
  );

  /// Renders [text] as a [format] barcode. [width]/[height] 0 = the smallest
  /// size; [margin] -1 = the symbology's default quiet zone; [ecLevel] 0–8
  /// (-1 = default) for QR, PDF417 and Aztec only — see `encode`. Throws if
  /// [text] can't be encoded in [format].
  ZxingImage writeBarcode(
    String text,
    ZxingFormat format,
    int width,
    int height,
    int margin,
    int ecLevel,
  );

  /// Encodes 8-bit luma [pixels] ([width]×[height], unpadded) as a PNG file.
  @zeroCopy
  Uint8List lumaToPng(@zeroCopy Uint8List pixels, int width, int height);
}
