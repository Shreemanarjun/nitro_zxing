import 'dart:typed_data';

import 'src/nitro_zxing.native.dart';

export 'src/nitro_zxing.native.dart'
    show NitroZxing, ZxingFormat, ZxingPixelFormat, ZxingResult;

/// Named-parameter decoding on top of [NitroZxing.readBarcodes].
extension NitroZxingDecode on NitroZxing {
  /// The first barcode in [pixels], or null when there is none.
  ///
  /// [rowStride] is in bytes (0 = unpadded rows). [formats] limits the
  /// symbologies searched; empty means all of them. [live] trades
  /// thoroughness for speed on a camera stream: a cheap scan per call, plus a
  /// rotation-tolerant scan on every 4th miss.
  ZxingResult? decode(
    Uint8List pixels, {
    required int width,
    required int height,
    int rowStride = 0,
    ZxingPixelFormat pixelFormat = ZxingPixelFormat.luma,
    Set<ZxingFormat> formats = const {},
    bool live = false,
  }) {
    final hits = readBarcodes(
      pixels,
      width,
      height,
      rowStride,
      pixelFormat,
      formats.toList(),
      live,
      1,
    );
    return hits.isEmpty ? null : hits.first;
  }

  /// Every barcode in [pixels], up to [maxSymbols] (0 = no limit). Parameters
  /// as in [decode].
  List<ZxingResult> decodeAll(
    Uint8List pixels, {
    required int width,
    required int height,
    int rowStride = 0,
    ZxingPixelFormat pixelFormat = ZxingPixelFormat.luma,
    Set<ZxingFormat> formats = const {},
    bool live = false,
    int maxSymbols = 0,
  }) => readBarcodes(
    pixels,
    width,
    height,
    rowStride,
    pixelFormat,
    formats.toList(),
    live,
    maxSymbols,
  );
}
