// Browser test of the WASM build. Build the module first, then run under BOTH
// web compilers — they differ at the js_interop boundary, so a green dart2js
// run does not imply dart2wasm:
//   emcmake cmake -S src -B build/web -DCMAKE_BUILD_TYPE=Release && cmake --build build/web
//   flutter test --platform chrome test/nitro_zxing_web_test.dart
//   flutter test --platform chrome --wasm test/nitro_zxing_web_test.dart
@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:nitro_zxing/nitro_zxing.dart';

void main() {
  late Uint8List qr; // 256×256 luma, rowStride 272, encodes https://margelo.com

  setUpAll(() async {
    final channel = spawnHybridUri('asset_server.dart');
    // dart2wasm hands JS numbers over as double — never cast with `as int`.
    final port = ((await channel.stream.first)! as num).toInt();
    await ensureNitroZxingReady(jsUrl: 'http://localhost:$port/nitro_zxing.js');
    final fixture = spawnHybridCode('''
      import 'dart:io';
      import 'package:stream_channel/stream_channel.dart';
      hybridMain(StreamChannel channel) =>
          channel.sink.add(File('test/native/qr_margelo_256_stride272.luma').readAsBytesSync());
    ''');
    qr = Uint8List.fromList([for (final b in (await fixture.stream.first)! as List) (b as num).toInt()]);
  });

  ZxingResult decode(Uint8List px, int formats) => NitroZxing.instance.decodeLuma(px, 256, 256, 272, formats, true);

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
    expect(decode(Uint8List(272 * 256)..fillRange(0, 272 * 256, 200), ZxingFormat.qrCode).text, isEmpty);
  });

  test('rejects a short buffer', () {
    expect(decode(Uint8List.fromList([1, 2, 3]), ZxingFormat.qrCode).text, isEmpty);
  });
}
