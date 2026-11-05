import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nitro_zxing/nitro_zxing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A 256×256 luma image (rowStride 272) holding a QR code — what a camera
  // frame's Y plane looks like. Real use: see nitro_camera's frame processor.
  final luma = (await rootBundle.load('assets/qr_nitro_256_stride272.luma'))
      .buffer
      .asUint8List();
  final r = NitroZxing.instance.decode(
    luma,
    width: 256,
    height: 256,
    rowStride: 272,
  );
  final result = r == null
      ? 'no code found'
      : '${r.text} (${r.format.name})\ncorners ${r.corners}';
  // Visible in device logs (profile and debug builds).
  debugPrint('nitro_zxing: $result');

  runApp(MaterialApp(home: ExampleScreen(result: result)));
}

class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key, required this.result});

  final String result;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('nitro_zxing')),
    body: Center(child: Text(result, textAlign: TextAlign.center)),
  );
}
