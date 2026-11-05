import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nitro_zxing/nitro_zxing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A 256×256 luma image (rowStride 272) holding a QR code — what a camera
  // frame's Y plane looks like. Real use: see nitro_camera's frame processor.
  final luma = (await rootBundle.load('assets/qr_margelo_256_stride272.luma'))
      .buffer
      .asUint8List();
  final r = NitroZxing.instance.decodeLuma(
    luma,
    256,
    256,
    272,
    ZxingFormat.all,
    false,
  );
  final result = r.text.isEmpty
      ? 'no code found'
      : '${r.text}\ncorners ${r.corners}';
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
