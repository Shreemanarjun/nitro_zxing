import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nitro_zxing/nitro_zxing.dart';

Future<void> main() async {
  await ensureNitroZxingReady(); // loads the wasm module on web; no-op elsewhere
  runApp(const MaterialApp(home: ExampleScreen()));
}

/// Decodes a blank 64×64 luma image — proves the native library loads.
/// Real use: pass a camera frame's Y plane (see nitro_camera's QR bench).
class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = NitroZxing.instance.decodeLuma(Uint8List(64 * 64), 64, 64, 64, ZxingFormat.all, false);
    return Scaffold(
      appBar: AppBar(title: const Text('nitro_zxing')),
      body: Center(child: Text(r.text.isEmpty ? 'zxing-cpp loaded — no code in a blank image' : r.text)),
    );
  }
}
