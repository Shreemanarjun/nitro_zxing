import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nitro_zxing/nitro_zxing.dart';

final zxing = NitroZxing.instance;

void main() => runApp(
  MaterialApp(
    title: 'nitro_zxing',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _AppBar(),
        body: TabBarView(children: [DecodeTab(), GenerateTab()]),
      ),
    ),
  ),
);

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Size get preferredSize => const Size.fromHeight(104);

  @override
  Widget build(BuildContext context) => AppBar(
    title: const Text('nitro_zxing'),
    bottom: const TabBar(
      tabs: [
        Tab(icon: Icon(Icons.qr_code_scanner), text: 'Decode'),
        Tab(icon: Icon(Icons.qr_code_2), text: 'Generate'),
      ],
    ),
  );
}

// ── Decode ───────────────────────────────────────────────────────────────────

/// Something to decode: raw luma pixels, or an image file.
sealed class Sample {
  final String name;
  const Sample(this.name);
}

class RawSample extends Sample {
  final ZxingImage image;
  final int rowStride;
  const RawSample(super.name, this.image, [this.rowStride = 0]);
}

class FileSample extends Sample {
  final Uint8List png;
  const FileSample(super.name, this.png);
}

Future<List<Sample>> loadSamples() async {
  Future<Uint8List> asset(String name) async =>
      (await rootBundle.load('assets/$name')).buffer.asUint8List();
  // Generated with nitro_zxing itself.
  RawSample generated(String name, String text, ZxingFormat format) =>
      RawSample(name, zxing.encode(text, format: format, width: 300));
  return [
    // A raw 256×256 luma frame with padded rows, like a camera's Y plane.
    RawSample(
      'QR (camera frame)',
      ZxingImage(
        width: 256,
        height: 256,
        pixels: await asset('qr_nitro_256_stride272.luma'),
      ),
      272,
    ),
    generated('EAN-13', '5901234123457', ZxingFormat.ean13),
    generated('Code 128', 'NITRO-128', ZxingFormat.code128),
    generated('Data Matrix', 'nitro_zxing', ZxingFormat.dataMatrix),
    generated('Aztec', 'Aztec 123', ZxingFormat.aztec),
    generated('PDF417', 'PDF417 text', ZxingFormat.pdf417),
    // zxing-cpp samples of formats nitro_zxing reads but can't write.
    FileSample('rMQR', await asset('rmqr.png')),
    FileSample('MaxiCode', await asset('maxicode.png')),
    FileSample('GS1 DataBar', await asset('databar.png')),
    FileSample('DataBar Expanded', await asset('databar_expanded.png')),
    FileSample('DataBar Limited', await asset('databar_limited.png')),
  ];
}

class DecodeTab extends StatelessWidget {
  const DecodeTab({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: loadSamples(),
    builder: (context, snap) {
      final samples = snap.data;
      if (samples == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: samples.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, i) => SampleCard(samples[i]),
      );
    },
  );
}

class SampleCard extends StatelessWidget {
  final Sample sample;
  const SampleCard(this.sample, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = sample;
    final (png, imageSize, result) = switch (s) {
      FileSample(:final png) => (png, null, zxing.decodeImage(png)),
      RawSample(:final image, :final rowStride) => (
        _unpadded(image, rowStride).toPng(),
        Size(image.width.toDouble(), image.height.toDouble()),
        zxing.decode(
          image.pixels,
          width: image.width,
          height: image.height,
          rowStride: rowStride,
        ),
      ),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Center(
              child: _Highlighted(
                png: png,
                imageSize: imageSize,
                result: result,
              ),
            ),
            const SizedBox(height: 8),
            if (result == null)
              const Text('No barcode found')
            else ...[
              SelectableText(
                result.text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${result.format.name} · ${result.contentType.name}'
                '${result.ecLevel.isEmpty ? '' : ' · EC ${result.ecLevel}'}'
                ' · ${result.orientation}° · bounds ${result.bounds}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// [image] with rows [rowStride] bytes apart, repacked unpadded for display.
ZxingImage _unpadded(ZxingImage image, int rowStride) {
  if (rowStride == 0 || rowStride == image.width) return image;
  final out = Uint8List(image.width * image.height);
  for (var y = 0; y < image.height; y++) {
    out.setRange(
      y * image.width,
      (y + 1) * image.width,
      image.pixels,
      y * rowStride,
    );
  }
  return ZxingImage(width: image.width, height: image.height, pixels: out);
}

/// The image with the decoded barcode's outline drawn on top (when the image
/// size is known, i.e. for raw pixels).
class _Highlighted extends StatelessWidget {
  final Uint8List png;
  final Size? imageSize;
  final ZxingResult? result;
  const _Highlighted({
    required this.png,
    required this.imageSize,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(
      png,
      height: 160,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
    );
    final size = imageSize, r = result;
    if (size == null || r == null) return image;
    return SizedBox(
      height: 160,
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: CustomPaint(foregroundPainter: _Outline(r, size), child: image),
      ),
    );
  }
}

class _Outline extends CustomPainter {
  final ZxingResult result;
  final Size image;
  _Outline(this.result, this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / image.width, sy = size.height / image.height;
    Offset p(({int x, int y}) c) => Offset(c.x * sx, c.y * sy);
    final r = result;
    canvas.drawPath(
      Path()..addPolygon([
        p(r.topLeft),
        p(r.topRight),
        p(r.bottomRight),
        p(r.bottomLeft),
      ], true),
      Paint()
        ..color = Colors.greenAccent.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_Outline old) => old.result != result;
}

// ── Generate ─────────────────────────────────────────────────────────────────

class GenerateTab extends StatefulWidget {
  const GenerateTab({super.key});

  @override
  State<GenerateTab> createState() => _GenerateTabState();
}

class _GenerateTabState extends State<GenerateTab> {
  final _text = TextEditingController(text: 'https://nitro.shreeman.dev');
  var _format = ZxingFormat.qrCode;
  var _ecLevel = ZxingQrEcLevel.medium;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Encode, then read the result back: proves what was written decodes.
    final (png, readBack, error) = (() {
      try {
        final png = zxing.encodePng(
          _text.text,
          format: _format,
          width: 280,
          ecLevel: _format == ZxingFormat.qrCode ? _ecLevel : null,
        );
        return (png, zxing.decodeImage(png, formats: {_format})?.text, null);
      } catch (e) {
        return (null, null, '$e');
      }
    })();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _text,
          decoration: const InputDecoration(
            labelText: 'Text',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField(
          initialValue: _format,
          decoration: const InputDecoration(
            labelText: 'Format',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final f in ZxingFormats.writable)
              DropdownMenuItem(value: f, child: Text(f.name)),
          ],
          onChanged: (f) => setState(() => _format = f!),
        ),
        if (_format == ZxingFormat.qrCode) ...[
          const SizedBox(height: 12),
          SegmentedButton(
            segments: const [
              ButtonSegment(value: ZxingQrEcLevel.low, label: Text('L')),
              ButtonSegment(value: ZxingQrEcLevel.medium, label: Text('M')),
              ButtonSegment(value: ZxingQrEcLevel.quartile, label: Text('Q')),
              ButtonSegment(value: ZxingQrEcLevel.high, label: Text('H')),
            ],
            selected: {_ecLevel},
            onSelectionChanged: (s) => setState(() => _ecLevel = s.first),
          ),
        ],
        const SizedBox(height: 24),
        if (png != null) ...[
          Center(
            child: Image.memory(
              png,
              width: 280,
              filterQuality: FilterQuality.none,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Reads back as: ${readBack ?? '(nothing)'}',
            textAlign: TextAlign.center,
          ),
        ] else
          Text(
            error ?? '',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
