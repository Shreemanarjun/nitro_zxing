// Pure Dart (no Flutter engine) decode tests on the Dart VM. hook/build.dart
// builds the native library on first run:
//   dart test
// Fixtures in test/native/ are raw 8-bit luma.
@TestOn('vm')
library;

import 'dart:convert';
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
  final qr = Luma.file('qr_nitro_256_stride272.luma', 256, 256, 272);
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
      expect(r.text, 'https://nitro.shreeman.dev');
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
        expect(r?.text, 'https://nitro.shreeman.dev');
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
        'https://nitro.shreeman.dev',
      );
      expect(decode(qr.restrided(400))?.text, 'https://nitro.shreeman.dev');
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

  group('format groups', () {
    test('linear / matrix / retail select the right families', () {
      expect(decode(ean13, formats: ZxingFormats.matrix), isNull);
      expect(
        decode(ean13, formats: ZxingFormats.linear)?.format,
        ZxingFormat.ean13,
      );
      expect(
        decode(ean13, formats: ZxingFormats.retail)?.format,
        ZxingFormat.ean13,
      );
      expect(decode(qr, formats: ZxingFormats.linear), isNull);
      expect(ZxingFormats.all, ZxingFormat.values.toSet());
    });
  });

  group('result details', () {
    test('QR metadata', () {
      final r = decode(qr)!;
      expect(r.bytes, utf8.encode('https://nitro.shreeman.dev'));
      expect(r.contentType, ZxingContentType.text);
      expect(r.symbologyIdentifier, startsWith(']Q'));
      expect(r.ecLevel, isNotEmpty);
      expect((r.orientation, r.isMirrored, r.isInverted), (0, false, false));
    });
    test('textMode hex renders the bytes as hex', () {
      final r = zxing.decode(
        qr.bytes,
        width: qr.width,
        height: qr.height,
        rowStride: qr.stride,
        options: const ZxingReaderOptions(textMode: ZxingTextMode.hex),
      )!;
      expect(
        r.text.toLowerCase().replaceAll(' ', ''),
        r.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      );
    });
  });

  group('reader options', () {
    final inverted = Luma(
      Uint8List.fromList([
        for (final b in qr.restrided(qr.width).bytes) 255 - b,
      ]),
      qr.width,
      qr.height,
    );
    ZxingResult? decodeInverted(ZxingReaderOptions o) => zxing.decode(
      inverted.bytes,
      width: inverted.width,
      height: inverted.height,
      options: o,
    );
    test('tryInvert finds light-on-dark codes and flags them', () {
      final r = decodeInverted(const ZxingReaderOptions())!;
      expect((r.text, r.isInverted), ('https://nitro.shreeman.dev', true));
      expect(
        decodeInverted(const ZxingReaderOptions(tryInvert: false)),
        isNull,
      );
    });
    test('isPure and every binarizer decode a clean generated code', () {
      final img = zxing.encode(
        'pure',
        format: ZxingFormat.dataMatrix,
        width: 120,
        height: 120,
      );
      for (final b in ZxingBinarizer.values) {
        final r = zxing.decode(
          img.pixels,
          width: img.width,
          height: img.height,
          options: ZxingReaderOptions(isPure: true, binarizer: b),
        );
        expect(r?.text, 'pure', reason: b.name);
      }
    });
  });

  group('region of interest', () {
    final both = sideBySide(qr.restrided(qr.width), ean13);
    ZxingResult? inRegion(ZxingRegion region) => zxing.decode(
      both.bytes,
      width: both.width,
      height: both.height,
      region: region,
    );
    test('searches only the region, corners in full-image coordinates', () {
      final r = inRegion((left: 256, top: 0, width: 300, height: 120))!;
      expect(r.format, ZxingFormat.ean13);
      for (var i = 0; i < r.corners.length; i += 2) {
        expect(r.corners[i], greaterThanOrEqualTo(256));
      }
      expect(
        inRegion((left: 0, top: 0, width: 256, height: 256))?.format,
        ZxingFormat.qrCode,
      );
    });
    test('empty or out-of-bounds region finds nothing', () {
      expect(inRegion((left: 0, top: 200, width: 256, height: 56)), isNull);
      expect(inRegion((left: 500, top: 0, width: 300, height: 120)), isNull);
    });
  });

  group('image files', () {
    test('decodes a PNG file', () {
      final tight = qr.restrided(qr.width);
      final png = ZxingImage(
        width: tight.width,
        height: tight.height,
        pixels: tight.bytes,
      ).toPng();
      expect(png.sublist(1, 4), ascii.encode('PNG'));
      expect(zxing.decodeImage(png)?.text, 'https://nitro.shreeman.dev');
    });
    test('decodeImageAll and a non-image file', () {
      final both = sideBySide(qr.restrided(qr.width), ean13);
      final png = ZxingImage(
        width: both.width,
        height: both.height,
        pixels: both.bytes,
      ).toPng();
      expect(zxing.decodeImageAll(png).map((r) => r.format).toSet(), {
        ZxingFormat.qrCode,
        ZxingFormat.ean13,
      });
      expect(
        zxing.decodeImage(Uint8List.fromList(utf8.encode('not an image'))),
        isNull,
      );
    });
  });

  group('encoding', () {
    // format: (text to write, text read back). zxing-cpp reports UPC-A/E as
    // 13-digit GTIN: UPC-A gains a leading 0, UPC-E expands to EAN-13 form.
    const samples = {
      ZxingFormat.qrCode: ('https://dart.dev', 'https://dart.dev'),
      ZxingFormat.aztec: ('Aztec 123', 'Aztec 123'),
      ZxingFormat.dataMatrix: ('DataMatrix', 'DataMatrix'),
      ZxingFormat.pdf417: ('PDF417 text', 'PDF417 text'),
      ZxingFormat.code128: ('CODE-128', 'CODE-128'),
      ZxingFormat.code39: ('CODE39', 'CODE39'),
      ZxingFormat.code93: ('CODE93', 'CODE93'),
      ZxingFormat.codabar: ('A123456A', 'A123456A'),
      ZxingFormat.ean13: ('5901234123457', '5901234123457'),
      ZxingFormat.ean8: ('96385074', '96385074'),
      ZxingFormat.upcA: ('036000291452', '0036000291452'),
      ZxingFormat.upcE: ('01234565', '0012345000065'),
      ZxingFormat.itf: ('00012345678905', '00012345678905'),
    };
    for (final MapEntry(key: format, value: (text, readBack))
        in samples.entries) {
      test('${format.name} round-trips', () {
        // The size is a hint: writers keep the symbol's aspect ratio.
        final img = zxing.encode(text, format: format, width: 300, height: 150);
        expect(img.pixels, hasLength(img.width * img.height));
        final r = zxing.decode(
          img.pixels,
          width: img.width,
          height: img.height,
          formats: {format},
        );
        expect((r?.text, r?.format), (readBack, format));
      });
    }
    test('smallest size, margin and PNG output', () {
      final small = zxing.encode('hi', format: ZxingFormat.qrCode, margin: 0);
      expect(small.width, 21); // QR version 1, no quiet zone
      final png = zxing.encodePng(
        'hi',
        format: ZxingFormat.qrCode,
        width: 200,
        height: 200,
      );
      expect(zxing.decodeImage(png)?.text, 'hi');
    });
    test('QR ecLevel 0–8 maps to L/M/Q/H; out of range is ignored', () {
      String levelOf(int? ecLevel) {
        final img = zxing.encode(
          'ec',
          format: ZxingFormat.qrCode,
          ecLevel: ecLevel,
        );
        return zxing
            .decode(img.pixels, width: img.width, height: img.height)!
            .ecLevel;
      }

      expect([null, 0, 2, 3, 4, 5, 6, 7, 8, 9].map(levelOf), [
        'L',
        'L',
        'L',
        'M',
        'M',
        'Q',
        'Q',
        'H',
        'H',
        'L',
      ]);
    });
    test('throws on text the format cannot hold, and on Micro QR', () {
      expect(
        () => zxing.encode('letters', format: ZxingFormat.ean13),
        throwsA(anything),
      );
      expect(
        () => zxing.encode('hi', format: ZxingFormat.microQrCode),
        throwsA(anything),
      );
    });
  });

  group('async', () {
    test('decodeAsync and decodeImageAsync run off-isolate', () async {
      expect(
        (await zxing.decodeAsync(
          qr.bytes,
          width: qr.width,
          height: qr.height,
          rowStride: qr.stride,
        ))?.text,
        'https://nitro.shreeman.dev',
      );
      final png = zxing.encodePng(
        'async',
        format: ZxingFormat.qrCode,
        width: 120,
        height: 120,
      );
      expect((await zxing.decodeImageAsync(png))?.text, 'async');
    });
  });
}
