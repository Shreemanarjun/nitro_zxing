# nitro_zxing example

A two-tab Flutter app showing the whole API:

- **Decode** — decodes a raw camera-style luma frame, barcodes generated with
  `encode`, and zxing-cpp samples of the read-only formats (rMQR, MaxiCode,
  GS1 DataBar), drawing each result's outline with `topLeft` … `bottomLeft`
  and listing its format, content type, error-correction level and `bounds`.
- **Generate** — type text, pick any writable format (and a QR
  error-correction level), and see the `encodePng` image plus what it reads
  back as.

```bash
flutter run
flutter test integration_test -d <device>   # on-device decode/encode checks
```

For plain Dart (CLI / server) see [../example_dart](../example_dart).
