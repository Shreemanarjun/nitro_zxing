// nitro_zxing from plain Dart: the package's build hook compiles and bundles
// the native library, nothing to set up.
//   dart run bin/main.dart [file.luma]
//   dart build cli -t bin/main.dart   # not `dart compile exe`: only `build`
//                                     # bundles the library next to the binary
import 'dart:io';

import 'package:nitro_zxing/nitro_zxing.dart';

void main(List<String> args) {
  // A 256×256 luma image (rowStride 272) holding a QR code.
  final luma = File(
    args.isNotEmpty ? args.first : '../test/native/qr_nitro_256_stride272.luma',
  ).readAsBytesSync();
  final r = NitroZxing.instance.decode(
    luma,
    width: 256,
    height: 256,
    rowStride: 272,
  );
  stdout.writeln(
    r == null ? 'no code found' : '${r.text} corners=${r.corners}',
  );
}
