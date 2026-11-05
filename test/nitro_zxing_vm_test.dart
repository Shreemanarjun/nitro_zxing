// Pure Dart (no Flutter engine) decode check on the Dart VM. hook/build.dart
// builds the native library on first run:
//   dart test test/nitro_zxing_vm_test.dart
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:nitro_zxing/nitro_zxing.dart';
import 'package:test/test.dart';

void main() {
  late Uint8List qr; // 256×256 luma, rowStride 272, encodes https://margelo.com

  setUpAll(() {
    qr = File('test/native/qr_margelo_256_stride272.luma').readAsBytesSync();
  });

  ZxingResult decode(Uint8List px, int formats) =>
      NitroZxing.instance.decodeLuma(px, 256, 256, 272, formats, true);

  // Same cases as test/native/decode_check.cpp.
  test('decodes a QR code with its corners', () {
    final r = decode(qr, ZxingFormat.qrCode);
    expect(r.text, 'https://margelo.com');
    expect(r.format, ZxingFormat.qrCode);
    expect(r.corners, hasLength(8));
  });

  test('misses when the format is not requested', () {
    expect(decode(qr, ZxingFormat.code128).text, isEmpty);
  });

  test('misses on a blank image', () {
    expect(
      decode(
        Uint8List(272 * 256)..fillRange(0, 272 * 256, 200),
        ZxingFormat.qrCode,
      ).text,
      isEmpty,
    );
  });

  test('rejects a short buffer', () {
    expect(
      decode(Uint8List.fromList([1, 2, 3]), ZxingFormat.qrCode).text,
      isEmpty,
    );
  });
}
