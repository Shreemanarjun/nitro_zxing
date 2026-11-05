// On-device check of the full Flutter → FFI → zxing-cpp path, same cases as
// test/native/decode_check.cpp:
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
    ZxingResult decode(Uint8List px, int formats) =>
        NitroZxing.instance.decodeLuma(px, 256, 256, 272, formats, true);

    final hit = decode(qr, ZxingFormat.qrCode);
    expect(hit.text, 'https://margelo.com');
    expect(hit.format, ZxingFormat.qrCode);
    expect(hit.corners, hasLength(8));
    expect(decode(qr, ZxingFormat.code128).text, isEmpty);
    expect(
      decode(
        Uint8List(272 * 256)..fillRange(0, 272 * 256, 200),
        ZxingFormat.qrCode,
      ).text,
      isEmpty,
    );
    expect(
      decode(Uint8List.fromList([1, 2, 3]), ZxingFormat.qrCode).text,
      isEmpty,
    );
  });
}
