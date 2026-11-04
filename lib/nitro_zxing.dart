export 'src/nitro_zxing.native.dart' show NitroZxing, ZxingResult;

/// Bit values for `NitroZxing.decodeLuma`'s `formats` mask (OR them together).
/// Mirrored in src/NitroZxingImpl.cpp.
abstract final class ZxingFormat {
  static const qrCode = 1 << 0;
  static const aztec = 1 << 1;
  static const dataMatrix = 1 << 2;
  static const pdf417 = 1 << 3;
  static const code128 = 1 << 4;
  static const code39 = 1 << 5;
  static const code93 = 1 << 6;
  static const codabar = 1 << 7;
  static const ean13 = 1 << 8;
  static const ean8 = 1 << 9;
  static const upcA = 1 << 10;
  static const upcE = 1 << 11;
  static const itf = 1 << 12;
  static const microQrCode = 1 << 13;

  /// Every format above.
  static const all = (1 << 14) - 1;
}
