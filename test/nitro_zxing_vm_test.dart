// Pure Dart (no Flutter engine) decode tests on the Dart VM. hook/build.dart
// builds the native library on first run:
//   dart test
// Fixtures in test/native/ are raw 8-bit luma.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:nitro_zxing/nitro_zxing.dart';
import 'package:test/test.dart';

/// A raw luma image: [width]×[height], rows [stride] bytes apart.
class Luma {
  final Uint8List bytes;
  final int width, height, stride;
  Luma(this.bytes, this.width, this.height, [int? stride])
    : stride = stride ?? width;
  Luma.file(String name, this.width, this.height, [int? stride])
    : bytes = File('test/native/$name').readAsBytesSync(),
      stride = stride ?? width;

  int at(int x, int y) => bytes[y * stride + x];

  /// Same pixels, rows [newStride] bytes apart.
  Luma restrided(int newStride) {
    final out = Uint8List(newStride * height);
    for (var y = 0; y < height; y++) {
      out.setRange(y * newStride, y * newStride + width, bytes, y * stride);
    }
    return Luma(out, width, height, newStride);
  }

  /// Rotated 90° clockwise.
  Luma rotated() {
    final out = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        out[x * height + (height - 1 - y)] = at(x, y);
      }
    }
    return Luma(out, height, width);
  }

  /// Expanded to [channels] bytes per pixel; the byte at [alphaAt] (if any) is
  /// opaque alpha. Rows get 8 bytes of padding to exercise the stride.
  ({Uint8List bytes, int stride}) toColor(int channels, {int alphaAt = -1}) {
    final rowBytes = width * channels + 8;
    final out = Uint8List(rowBytes * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        for (var c = 0; c < channels; c++) {
          out[y * rowBytes + x * channels + c] = c == alphaAt ? 255 : at(x, y);
        }
      }
    }
    return (bytes: out, stride: rowBytes);
  }
}

/// [a] and [b] side by side on a white background.
Luma sideBySide(Luma a, Luma b) {
  final w = a.width + b.width, h = a.height > b.height ? a.height : b.height;
  final out = Uint8List(w * h)..fillRange(0, w * h, 255);
  for (var y = 0; y < a.height; y++) {
    for (var x = 0; x < a.width; x++) {
      out[y * w + x] = a.at(x, y);
    }
  }
  for (var y = 0; y < b.height; y++) {
    for (var x = 0; x < b.width; x++) {
      out[y * w + a.width + x] = b.at(x, y);
    }
  }
  return Luma(out, w, h);
}

void main() {
  final zxing = NitroZxing.instance;
  final qr = Luma.file('qr_margelo_256_stride272.luma', 256, 256, 272);
  final ean13 = Luma.file('ean13.luma', 300, 120);
  final code128 = Luma.file('code128.luma', 300, 120);
  final dataMatrix = Luma.file('datamatrix.luma', 120, 120);

  ZxingResult? decode(
    Luma img, {
    Set<ZxingFormat> formats = const {},
    bool live = false,
  }) => zxing.decode(
    img.bytes,
    width: img.width,
    height: img.height,
    rowStride: img.stride,
    formats: formats,
    live: live,
  );

  group('symbologies', () {
    test('QR code, with corners', () {
      final r = decode(qr)!;
      expect(r.text, 'https://margelo.com');
      expect(r.format, ZxingFormat.qrCode);
      expect(r.corners, hasLength(8));
    });
    test('EAN-13', () {
      final r = decode(ean13)!;
      expect((r.text, r.format), ('5901234123457', ZxingFormat.ean13));
    });
    test('Code 128', () {
      final r = decode(code128)!;
      expect((r.text, r.format), ('NITRO-128', ZxingFormat.code128));
    });
    test('Data Matrix', () {
      final r = decode(dataMatrix)!;
      expect((r.text, r.format), ('nitro_zxing', ZxingFormat.dataMatrix));
    });
  });

  test('formats filter finds only requested formats', () {
    expect(decode(qr, formats: {ZxingFormat.code128}), isNull);
    expect(decode(ean13, formats: {ZxingFormat.qrCode}), isNull);
    expect(
      decode(ean13, formats: {ZxingFormat.qrCode, ZxingFormat.ean13})?.format,
      ZxingFormat.ean13,
    );
  });

  group('pixel formats', () {
    const layouts = {
      ZxingPixelFormat.bgra: (4, 3),
      ZxingPixelFormat.rgba: (4, 3),
      ZxingPixelFormat.rgb: (3, -1),
      ZxingPixelFormat.bgr: (3, -1),
    };
    for (final MapEntry(key: format, value: (channels, alphaAt))
        in layouts.entries) {
      test(format.name, () {
        final px = qr.toColor(channels, alphaAt: alphaAt);
        final r = zxing.decode(
          px.bytes,
          width: qr.width,
          height: qr.height,
          rowStride: px.stride,
          pixelFormat: format,
        );
        expect(r?.text, 'https://margelo.com');
      });
    }
  });

  group('row stride', () {
    test('unpadded (rowStride 0) and extra-padded rows decode', () {
      final tight = qr.restrided(qr.width);
      expect(
        zxing
            .decode(tight.bytes, width: tight.width, height: tight.height)
            ?.text,
        'https://margelo.com',
      );
      expect(decode(qr.restrided(400))?.text, 'https://margelo.com');
    });
    test('rejects a stride narrower than a row', () {
      expect(decode(Luma(qr.bytes, qr.width, qr.height, 100)), isNull);
    });
  });

  group('rotation', () {
    final rotated = ean13.rotated();
    test('non-live decodes a rotated 1D code', () {
      expect(decode(rotated)?.text, '5901234123457');
    });
    test('live finds it within one ladder period (4 calls)', () {
      final hits = [for (var i = 0; i < 4; i++) decode(rotated, live: true)]
          .whereType<ZxingResult>();
      expect(hits.map((r) => r.text), contains('5901234123457'));
    });
  });

  group('multiple codes', () {
    final both = sideBySide(qr.restrided(qr.width), ean13);
    test('decodeAll finds every code', () {
      final all = zxing.decodeAll(
        both.bytes,
        width: both.width,
        height: both.height,
      );
      expect(all.map((r) => r.format).toSet(), {
        ZxingFormat.qrCode,
        ZxingFormat.ean13,
      });
    });
    test('maxSymbols and decode cap the count', () {
      final one = zxing.decodeAll(
        both.bytes,
        width: both.width,
        height: both.height,
        maxSymbols: 1,
      );
      expect(one, hasLength(1));
      expect(decode(both), isNotNull);
    });
  });

  group('misses', () {
    test('blank image', () {
      final blank = Uint8List(272 * 256)..fillRange(0, 272 * 256, 200);
      expect(decode(Luma(blank, 256, 256, 272)), isNull);
    });
    test('short buffer', () {
      expect(
        decode(Luma(Uint8List.fromList([1, 2, 3]), 256, 256, 272)),
        isNull,
      );
    });
  });
}
