import 'dart:isolate';
import 'dart:typed_data';

import 'src/nitro_zxing.native.dart';

export 'src/nitro_zxing.native.dart'
    show
        NitroZxing,
        ZxingBinarizer,
        ZxingContentType,
        ZxingFormat,
        ZxingImage,
        ZxingPixelFormat,
        ZxingResult,
        ZxingTextMode;

/// Ready-made [ZxingFormat] groups for the `formats` parameter.
abstract final class ZxingFormats {
  /// 1D (linear) barcodes: retail, logistics.
  static const linear = {
    ZxingFormat.codabar,
    ZxingFormat.code39,
    ZxingFormat.code93,
    ZxingFormat.code128,
    ZxingFormat.ean8,
    ZxingFormat.ean13,
    ZxingFormat.itf,
    ZxingFormat.upcA,
    ZxingFormat.upcE,
    ZxingFormat.dataBar,
    ZxingFormat.dataBarExpanded,
    ZxingFormat.dataBarLimited,
  };

  /// 2D (matrix and stacked) codes.
  static const matrix = {
    ZxingFormat.qrCode,
    ZxingFormat.microQrCode,
    ZxingFormat.rmqrCode,
    ZxingFormat.aztec,
    ZxingFormat.dataMatrix,
    ZxingFormat.pdf417,
    ZxingFormat.maxiCode,
  };

  /// Retail product codes (EAN / UPC).
  static const retail = {
    ZxingFormat.ean8,
    ZxingFormat.ean13,
    ZxingFormat.upcA,
    ZxingFormat.upcE,
  };

  /// GS1 DataBar variants (retail, coupons, fresh food).
  static const dataBar = {
    ZxingFormat.dataBar,
    ZxingFormat.dataBarExpanded,
    ZxingFormat.dataBarLimited,
  };

  /// Formats `encode` / `encodePng` can write (every format but Micro QR,
  /// rMQR, MaxiCode and DataBar, which zxing-cpp's writers don't support).
  static const writable = {
    ZxingFormat.qrCode,
    ZxingFormat.aztec,
    ZxingFormat.dataMatrix,
    ZxingFormat.pdf417,
    ZxingFormat.code128,
    ZxingFormat.code39,
    ZxingFormat.code93,
    ZxingFormat.codabar,
    ZxingFormat.ean13,
    ZxingFormat.ean8,
    ZxingFormat.upcA,
    ZxingFormat.upcE,
    ZxingFormat.itf,
  };

  /// Every format (the same as passing an empty set).
  static const all = {...linear, ...matrix};
}

/// Named `ecLevel` values for QR codes in `encode` / `encodePng`.
abstract final class ZxingQrEcLevel {
  /// L, recovers ~7 % (the default).
  static const low = 0;

  /// M, recovers ~15 %.
  static const medium = 3;

  /// Q, recovers ~25 %.
  static const quartile = 5;

  /// H, recovers ~30 %: survives logos and damage best.
  static const high = 7;
}

/// A rectangle of the image to search, in pixels.
typedef ZxingRegion = ({int left, int top, int width, int height});

/// Mapping a region from image pixels to screen space.
extension ZxingRegionScaling on ZxingRegion {
  /// This region scaled by [sx] horizontally and [sy] (default [sx])
  /// vertically, e.g. from a 1920×1080 frame to a 390×219 preview:
  /// `r.bounds.scale(390 / 1920)`.
  ({double left, double top, double width, double height}) scale(
    double sx, [
    double? sy,
  ]) => (
    left: left * sx,
    top: top * (sy ?? sx),
    width: width * sx,
    height: height * (sy ?? sx),
  );
}

/// Advanced reader settings. The `try*` flags default (null) to "thorough
/// unless `live`".
class ZxingReaderOptions {
  /// Spend more time looking for barcodes.
  final bool? tryHarder;

  /// Also try the image rotated by 90/180/270°.
  final bool? tryRotate;

  /// Also try light-on-dark (inverted) barcodes.
  final bool? tryInvert;

  /// Also try downscaled versions of large images.
  final bool? tryDownscale;

  /// The image is a clean, axis-aligned barcode with no background
  /// (e.g. a generated image); ~1.6× faster on a 256×256 generated QR.
  final bool isPure;
  final ZxingBinarizer binarizer;
  final ZxingTextMode textMode;

  const ZxingReaderOptions({
    this.tryHarder,
    this.tryRotate,
    this.tryInvert,
    this.tryDownscale,
    this.isPure = false,
    this.binarizer = ZxingBinarizer.localAverage,
    this.textMode = ZxingTextMode.hri,
  });

  /// No extra search passes, whatever `live` says: for high-frame-rate
  /// camera streams (with `live: true` the rotation ladder still runs).
  static const fast = ZxingReaderOptions(
    tryHarder: false,
    tryRotate: false,
    tryInvert: false,
    tryDownscale: false,
  );

  /// Every extra search pass, even with `live`: for damaged, noisy or
  /// tricky photos.
  static const thorough = ZxingReaderOptions(
    tryHarder: true,
    tryRotate: true,
    tryInvert: true,
    tryDownscale: true,
  );

  /// Clean, digitally rendered barcodes (screenshots, generated images).
  static const pure = ZxingReaderOptions(isPure: true);

  /// A copy with the given fields replaced (a `try*` flag can't be reset to
  /// null "follow `live`" this way; build a new [ZxingReaderOptions] for that).
  ZxingReaderOptions copyWith({
    bool? tryHarder,
    bool? tryRotate,
    bool? tryInvert,
    bool? tryDownscale,
    bool? isPure,
    ZxingBinarizer? binarizer,
    ZxingTextMode? textMode,
  }) => ZxingReaderOptions(
    tryHarder: tryHarder ?? this.tryHarder,
    tryRotate: tryRotate ?? this.tryRotate,
    tryInvert: tryInvert ?? this.tryInvert,
    tryDownscale: tryDownscale ?? this.tryDownscale,
    isPure: isPure ?? this.isPure,
    binarizer: binarizer ?? this.binarizer,
    textMode: textMode ?? this.textMode,
  );

  ZxingReadOptions _resolve(
    Set<ZxingFormat> formats,
    bool live,
    int maxSymbols,
    ZxingRegion? region,
  ) => ZxingReadOptions(
    formats: formats.toList(),
    tryHarder: tryHarder ?? !live,
    tryRotate: tryRotate ?? !live,
    tryInvert: tryInvert ?? !live,
    tryDownscale: tryDownscale ?? !live,
    isPure: isPure,
    binarizer: binarizer,
    textMode: textMode,
    maxSymbols: maxSymbols,
    live: live,
    regionLeft: region?.left ?? 0,
    regionTop: region?.top ?? 0,
    regionWidth: region?.width ?? 0,
    regionHeight: region?.height ?? 0,
  );
}

/// Geometry helpers for drawing overlays, from [ZxingResult.corners].
extension ZxingResultGeometry on ZxingResult {
  ({int x, int y}) _corner(int i) => (x: corners[2 * i], y: corners[2 * i + 1]);
  ({int x, int y}) get topLeft => _corner(0);
  ({int x, int y}) get topRight => _corner(1);
  ({int x, int y}) get bottomRight => _corner(2);
  ({int x, int y}) get bottomLeft => _corner(3);

  /// The four corners, clockwise from [topLeft].
  List<({int x, int y})> get points => [
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
  ];

  /// The centre of [bounds], e.g. for an aiming reticle or a tooltip.
  ({double x, double y}) get center {
    final b = bounds;
    return (x: b.left + b.width / 2, y: b.top + b.height / 2);
  }

  /// The axis-aligned rectangle enclosing the four corners.
  ZxingRegion get bounds {
    var (minX, minY, maxX, maxY) = (
      corners[0],
      corners[1],
      corners[0],
      corners[1],
    );
    for (var i = 2; i < corners.length; i += 2) {
      if (corners[i] < minX) minX = corners[i];
      if (corners[i] > maxX) maxX = corners[i];
      if (corners[i + 1] < minY) minY = corners[i + 1];
      if (corners[i + 1] > maxY) maxY = corners[i + 1];
    }
    return (left: minX, top: minY, width: maxX - minX, height: maxY - minY);
  }
}

/// Readable output for a [ZxingResult] (its default `toString` is
/// `Instance of 'ZxingResult'`).
extension ZxingResultFormatting on ZxingResult {
  /// One line, e.g. `qrCode: "https://dart.dev" at (15, 15, 225x225)`.
  String toDisplayString() {
    final b = bounds;
    return '${format.name}: "$text" at (${b.left}, ${b.top}, ${b.width}x${b.height})';
  }
}

/// The PNG encoding of this image.
extension ZxingImagePng on ZxingImage {
  Uint8List toPng() => NitroZxing.instance.lumaToPng(pixels, width, height);
}

/// Named-parameter reading and writing on top of the raw bridge calls.
extension NitroZxingDecode on NitroZxing {
  /// The first barcode in raw [pixels], or null when there is none.
  ///
  /// [rowStride] is in bytes (0 = unpadded rows). [formats] limits the
  /// symbologies searched (see [ZxingFormats]); empty means all. [live]
  /// trades thoroughness for speed on a camera stream: a cheap scan per call,
  /// plus a rotation-tolerant scan on every 4th miss. [region] limits the
  /// search to a rectangle (no copy); corners stay in full-image coordinates.
  ZxingResult? decode(
    Uint8List pixels, {
    required int width,
    required int height,
    int rowStride = 0,
    ZxingPixelFormat pixelFormat = ZxingPixelFormat.luma,
    Set<ZxingFormat> formats = const {},
    bool live = false,
    ZxingRegion? region,
    ZxingReaderOptions options = const ZxingReaderOptions(),
  }) => _first(
    readBarcodes(
      pixels,
      width,
      height,
      rowStride,
      pixelFormat,
      options._resolve(formats, live, 1, region),
    ),
  );

  /// Every barcode in raw [pixels], up to [maxSymbols] (0 = no limit).
  /// Parameters as in [decode].
  List<ZxingResult> decodeAll(
    Uint8List pixels, {
    required int width,
    required int height,
    int rowStride = 0,
    ZxingPixelFormat pixelFormat = ZxingPixelFormat.luma,
    Set<ZxingFormat> formats = const {},
    bool live = false,
    ZxingRegion? region,
    ZxingReaderOptions options = const ZxingReaderOptions(),
    int maxSymbols = 0,
  }) => readBarcodes(
    pixels,
    width,
    height,
    rowStride,
    pixelFormat,
    options._resolve(formats, live, maxSymbols, region),
  );

  /// The first barcode in an image file's bytes (PNG, JPEG, BMP, GIF, …), or
  /// null when there is none or the file can't be decoded.
  ZxingResult? decodeImage(
    Uint8List file, {
    Set<ZxingFormat> formats = const {},
    ZxingRegion? region,
    ZxingReaderOptions options = const ZxingReaderOptions(),
  }) => _first(
    readBarcodesFromImage(file, options._resolve(formats, false, 1, region)),
  );

  /// Every barcode in an image file's bytes, up to [maxSymbols] (0 = no limit).
  List<ZxingResult> decodeImageAll(
    Uint8List file, {
    Set<ZxingFormat> formats = const {},
    ZxingRegion? region,
    ZxingReaderOptions options = const ZxingReaderOptions(),
    int maxSymbols = 0,
  }) => readBarcodesFromImage(
    file,
    options._resolve(formats, false, maxSymbols, region),
  );

  /// [decode] on a background isolate, so it never blocks the caller (e.g.
  /// Flutter's UI isolate). [pixels] is copied to that isolate.
  Future<ZxingResult?> decodeAsync(
    Uint8List pixels, {
    required int width,
    required int height,
    int rowStride = 0,
    ZxingPixelFormat pixelFormat = ZxingPixelFormat.luma,
    Set<ZxingFormat> formats = const {},
    ZxingRegion? region,
    ZxingReaderOptions options = const ZxingReaderOptions(),
  }) => Isolate.run(
    () => NitroZxing.instance.decode(
      pixels,
      width: width,
      height: height,
      rowStride: rowStride,
      pixelFormat: pixelFormat,
      formats: formats,
      region: region,
      options: options,
    ),
  );

  /// [decodeAll] on a background isolate. [pixels] is copied to that isolate.
  Future<List<ZxingResult>> decodeAllAsync(
    Uint8List pixels, {
    required int width,
    required int height,
    int rowStride = 0,
    ZxingPixelFormat pixelFormat = ZxingPixelFormat.luma,
    Set<ZxingFormat> formats = const {},
    ZxingRegion? region,
    ZxingReaderOptions options = const ZxingReaderOptions(),
    int maxSymbols = 0,
  }) => Isolate.run(
    () => NitroZxing.instance
        .decodeAll(
          pixels,
          width: width,
          height: height,
          rowStride: rowStride,
          pixelFormat: pixelFormat,
          formats: formats,
          region: region,
          options: options,
          maxSymbols: maxSymbols,
        )
        .toList(), // nitro's native-backed list can't cross isolates
  );

  /// [decodeImage] on a background isolate.
  Future<ZxingResult?> decodeImageAsync(
    Uint8List file, {
    Set<ZxingFormat> formats = const {},
    ZxingRegion? region,
    ZxingReaderOptions options = const ZxingReaderOptions(),
  }) => Isolate.run(
    () => NitroZxing.instance.decodeImage(
      file,
      formats: formats,
      region: region,
      options: options,
    ),
  );

  /// [decodeImageAll] on a background isolate.
  Future<List<ZxingResult>> decodeImageAllAsync(
    Uint8List file, {
    Set<ZxingFormat> formats = const {},
    ZxingRegion? region,
    ZxingReaderOptions options = const ZxingReaderOptions(),
    int maxSymbols = 0,
  }) => Isolate.run(
    () => NitroZxing.instance
        .decodeImageAll(
          file,
          formats: formats,
          region: region,
          options: options,
          maxSymbols: maxSymbols,
        )
        .toList(), // nitro's native-backed list can't cross isolates
  );

  /// Renders [text] as a [format] barcode image (8-bit luma).
  ///
  /// [width]/[height] 0 = the smallest size that fits; larger sizes scale the
  /// modules up. A 1D code with [height] 0 is drawn 40 % as tall as it is
  /// wide; a square 2D code given only one of [width]/[height] uses it for
  /// both. [margin] is the quiet zone in pixels (null = the symbology's
  /// default). [ecLevel] is one 0–8 scale, higher = more error correction:
  /// QR 0–2 → L, 3–4 → M, 5–6 → Q, 7–8 → H (default L); PDF417 its level 0–8;
  /// Aztec a minimum of level × 12.5 % (short texts may get more). Ignored
  /// for other formats and outside 0–8 (see [ZxingQrEcLevel]).
  ///
  /// Throws an [ArgumentError] for a format outside [ZxingFormats.writable],
  /// and an exception if [text] can't be encoded in [format] (e.g. letters in
  /// an EAN-13).
  ZxingImage encode(
    String text, {
    required ZxingFormat format,
    int width = 0,
    int height = 0,
    int? margin,
    int? ecLevel,
  }) {
    if (!ZxingFormats.writable.contains(format)) {
      throw ArgumentError.value(
        format,
        'format',
        'zxing-cpp cannot write this format',
      );
    }
    final linear = ZxingFormats.linear.contains(format);
    var (w, h) = (width, height);
    if (!linear && format != ZxingFormat.pdf417 && (w == 0) != (h == 0)) {
      w = h = w + h; // square symbol: one given side sets both
    }
    final img = writeBarcode(text, format, w, h, margin ?? -1, ecLevel ?? -1);
    if (!linear || height > 0 || img.height != 1) return img;
    // zxing draws a height-0 1D code as a single row: repeat it.
    final rows = (img.width * 2 / 5).round();
    final pixels = Uint8List(img.width * rows);
    for (var y = 0; y < rows; y++) {
      pixels.setRange(y * img.width, (y + 1) * img.width, img.pixels);
    }
    return ZxingImage(width: img.width, height: rows, pixels: pixels);
  }

  /// [encode] straight to a PNG file's bytes (e.g. for Flutter's
  /// `Image.memory` or writing to disk).
  Uint8List encodePng(
    String text, {
    required ZxingFormat format,
    int width = 0,
    int height = 0,
    int? margin,
    int? ecLevel,
  }) => encode(
    text,
    format: format,
    width: width,
    height: height,
    margin: margin,
    ecLevel: ecLevel,
  ).toPng();
}

ZxingResult? _first(List<ZxingResult> hits) => hits.isEmpty ? null : hits.first;
