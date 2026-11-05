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
  };

  /// 2D (matrix) codes.
  static const matrix = {
    ZxingFormat.qrCode,
    ZxingFormat.microQrCode,
    ZxingFormat.aztec,
    ZxingFormat.dataMatrix,
    ZxingFormat.pdf417,
  };

  /// Retail product codes (EAN / UPC).
  static const retail = {
    ZxingFormat.ean8,
    ZxingFormat.ean13,
    ZxingFormat.upcA,
    ZxingFormat.upcE,
  };

  /// Every format (the same as passing an empty set).
  static const all = {...linear, ...matrix};
}

/// A rectangle of the image to search, in pixels.
typedef ZxingRegion = ({int left, int top, int width, int height});

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
  /// (e.g. a generated image); much faster.
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

  /// Renders [text] as a [format] barcode image (8-bit luma).
  ///
  /// [width]/[height] 0 = the smallest size that fits; larger sizes scale the
  /// modules up. [margin] is the quiet zone in pixels (null = the symbology's
  /// default). [ecLevel]: QR 0–3 (L/M/Q/H), PDF417 0–8, Aztec 0–100 (%).
  /// Throws if [text] can't be encoded in [format] (e.g. letters in an EAN-13,
  /// or [ZxingFormat.microQrCode], which can't be written).
  ZxingImage encode(
    String text, {
    required ZxingFormat format,
    int width = 0,
    int height = 0,
    int? margin,
    int? ecLevel,
  }) => writeBarcode(text, format, width, height, margin ?? -1, ecLevel ?? -1);

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
