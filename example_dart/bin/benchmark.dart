// Per-call timings of every nitro_zxing path. Run AOT for realistic numbers:
//   dart build cli -t bin/benchmark.dart -o build/bench
//   build/bench/bundle/bin/benchmark ../test/native/qr_margelo_256_stride272.luma
import 'dart:io';
import 'dart:typed_data';
import 'package:nitro_zxing/nitro_zxing.dart';

double us(int n, void Function() f) {
  for (var i = 0; i < n ~/ 10 + 1; i++) {
    f(); // warm-up
  }
  final sw = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    f();
  }
  return sw.elapsedMicroseconds / n;
}

Future<void> main(List<String> args) async {
  final z = NitroZxing.instance;
  final qr = File(args[0]).readAsBytesSync(); // 256x256, stride 272
  final tiny = Uint8List(8 * 8);
  final bgra = Uint8List(256 * 256 * 4);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      final v = qr[y * 272 + x];
      bgra.setAll((y * 256 + x) * 4, [v, v, v, 255]);
    }
  }
  final fhd = Uint8List(1920 * 1080)..fillRange(0, 1920 * 1080, 128);
  for (var y = 0; y < 256; y++) {
    fhd.setRange((400 + y) * 1920 + 800, (400 + y) * 1920 + 1056, qr, y * 272);
  }
  final png = z.encodePng(
    'https://margelo.com',
    format: ZxingFormat.qrCode,
    width: 256,
    height: 256,
  );

  final rows = <String, double>{
    'bridge round-trip (8x8 blank, live)': us(
      20000,
      () => z.decode(
        tiny,
        width: 8,
        height: 8,
        formats: {ZxingFormat.qrCode},
        live: true,
      ),
    ),
    'QR 256x256 luma, live, QR only': us(
      2000,
      () => z.decode(
        qr,
        width: 256,
        height: 256,
        rowStride: 272,
        formats: {ZxingFormat.qrCode},
        live: true,
      ),
    ),
    'QR 256x256 luma, live, all formats': us(
      2000,
      () => z.decode(qr, width: 256, height: 256, rowStride: 272, live: true),
    ),
    'QR 256x256 luma, thorough': us(
      500,
      () => z.decode(qr, width: 256, height: 256, rowStride: 272),
    ),
    'QR 256x256 BGRA, live, QR only': us(
      2000,
      () => z.decode(
        bgra,
        width: 256,
        height: 256,
        pixelFormat: ZxingPixelFormat.bgra,
        formats: {ZxingFormat.qrCode},
        live: true,
      ),
    ),
    '1080p frame, live, QR only': us(
      300,
      () => z.decode(
        fhd,
        width: 1920,
        height: 1080,
        formats: {ZxingFormat.qrCode},
        live: true,
      ),
    ),
    '1080p frame, live, QR, 256px region': us(
      2000,
      () => z.decode(
        fhd,
        width: 1920,
        height: 1080,
        formats: {ZxingFormat.qrCode},
        live: true,
        region: (left: 800, top: 400, width: 256, height: 256),
      ),
    ),
    'decodeImage (PNG 256x256)': us(500, () => z.decodeImage(png)),
    'encode QR 256x256': us(
      2000,
      () => z.encode(
        'https://margelo.com',
        format: ZxingFormat.qrCode,
        width: 256,
        height: 256,
      ),
    ),
    'encodePng QR 256x256': us(
      1000,
      () => z.encodePng(
        'https://margelo.com',
        format: ZxingFormat.qrCode,
        width: 256,
        height: 256,
      ),
    ),
  };
  final sw = Stopwatch()..start();
  for (var i = 0; i < 20; i++) {
    await z.decodeAsync(
      qr,
      width: 256,
      height: 256,
      rowStride: 272,
      formats: {ZxingFormat.qrCode},
    );
  }
  rows['decodeAsync (isolate per call)'] = sw.elapsedMicroseconds / 20;
  for (final e in rows.entries) {
    stdout.writeln(
      '${e.key.padRight(40)} ${e.value.toStringAsFixed(1).padLeft(9)} µs',
    );
  }
}
