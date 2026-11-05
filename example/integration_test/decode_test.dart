// On-device check of the full Flutter → FFI → zxing-cpp path, same cases as
// test/native/decode_check.cpp, plus BGRA, encoding, image files and a region:
//   flutter test integration_test -d <device>   (iOS, Android, macOS, Linux, Windows)
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nitro_zxing/nitro_zxing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('decodes the QR fixture', (_) async {
    final qr = (await rootBundle.load('assets/qr_margelo_256_stride272.luma'))
        .buffer
        .asUint8List();
    final zxing = NitroZxing.instance;
    ZxingResult? decode(Uint8List px, {Set<ZxingFormat> formats = const {}}) =>
        zxing.decode(
          px,
          width: 256,
          height: 256,
          rowStride: 272,
          formats: formats,
          live: true,
        );

    final hit = decode(qr, formats: {ZxingFormat.qrCode})!;
    expect(hit.text, 'https://margelo.com');
    expect(hit.format, ZxingFormat.qrCode);
    expect(hit.corners, hasLength(8));
    expect(decode(qr, formats: {ZxingFormat.code128}), isNull);
    expect(decode(Uint8List(272 * 256)..fillRange(0, 272 * 256, 200)), isNull);
    expect(decode(Uint8List.fromList([1, 2, 3])), isNull);

    // nitro_camera's default frame layout: BGRA, 4 bytes per pixel.
    final bgra = Uint8List(256 * 4 * 256);
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        final v = qr[y * 272 + x], o = (y * 256 + x) * 4;
        bgra.setAll(o, [v, v, v, 255]);
      }
    }
    expect(
      zxing
          .decode(
            bgra,
            width: 256,
            height: 256,
            pixelFormat: ZxingPixelFormat.bgra,
          )
          ?.text,
      'https://margelo.com',
    );

    // Writing, PNG output and image-file decoding (zxing writers + stb).
    final png = zxing.encodePng(
      'on-device',
      format: ZxingFormat.qrCode,
      width: 200,
      height: 200,
    );
    expect(zxing.decodeImage(png)?.text, 'on-device');
    expect((await zxing.decodeImageAsync(png))?.text, 'on-device');

    // Region of interest: only the top-left quarter, which holds no code.
    expect(
      zxing.decode(
        qr,
        width: 256,
        height: 256,
        rowStride: 272,
        region: (left: 0, top: 0, width: 64, height: 64),
      ),
      isNull,
    );
  });
}
