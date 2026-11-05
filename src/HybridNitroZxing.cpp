// nitro_zxing — zxing-cpp decoding behind the generated HybridNitroZxing
// interface. Live ladder after react-native-nitro-zxing (MIT, Marc Rousavy):
// a plain scan every call, and a rotation-tolerant scan on every 4th call
// that the plain scan missed.

#include "nitro_zxing.native.g.h"

#include "ReadBarcode.h"

#include <atomic>
#include <iterator>
#include <utility>
#include <vector>

namespace {

using ZXing::BarcodeFormat;

// Indexed by the generated ZxingFormat enum (lib/src/nitro_zxing.native.dart).
constexpr BarcodeFormat kFormats[] = {
    BarcodeFormat::QRCode, BarcodeFormat::MicroQRCode, BarcodeFormat::Aztec,
    BarcodeFormat::DataMatrix, BarcodeFormat::PDF417, BarcodeFormat::Code128,
    BarcodeFormat::Code39, BarcodeFormat::Code93, BarcodeFormat::Codabar,
    BarcodeFormat::EAN13, BarcodeFormat::EAN8, BarcodeFormat::UPCA,
    BarcodeFormat::UPCE, BarcodeFormat::ITF,
};
constexpr int64_t kFormatCount = static_cast<int64_t>(std::size(kFormats));

// Indexed by the generated ZxingPixelFormat enum: zxing layout, bytes per pixel.
constexpr std::pair<ZXing::ImageFormat, int> kPixelFormats[] = {
    {ZXing::ImageFormat::Lum, 1}, {ZXing::ImageFormat::BGRA, 4}, {ZXing::ImageFormat::RGBA, 4},
    {ZXing::ImageFormat::RGB, 3}, {ZXing::ImageFormat::BGR, 3},
};

constexpr uint64_t kRotationPeriod = 4;
constexpr int kMaxSymbols = 255;  // zxing-cpp's own cap

// -1 for a symbology outside ZxingFormat (can't happen: the reader is limited to them).
int64_t formatOf(const ZXing::Barcode& b) {
  for (int64_t i = 0; i < kFormatCount; i++)
    if (b.format() == kFormats[i] || b.symbology() == kFormats[i]) return i;
  return -1;
}

NitroCppBuffer encode(const std::vector<ZxingResult>& results) {
  NitroRecordWriter w;
  w.writeIndexedList(results, [](NitroRecordWriter& w, const ZxingResult& r) { r.encodeInto(w); });
  return w.toNativeBuffer();
}

class NitroZxingImpl final : public HybridNitroZxing {
 public:
  NitroCppBuffer readBarcodes(const uint8_t* pixels, size_t pixels_length, int64_t width, int64_t height,
                              int64_t rowStride, ZxingPixelFormat pixelFormat, NitroCppBuffer formats,
                              bool live, int64_t maxSymbols) override {
    if (pixelFormat < 0 || pixelFormat >= static_cast<int>(std::size(kPixelFormats))) return encode({});
    const auto [imageFormat, bpp] = kPixelFormats[pixelFormat];
    const int64_t rowBytes = width * bpp;
    const int64_t stride = rowStride > 0 ? rowStride : rowBytes;
    if (!pixels || width <= 0 || height <= 0 || stride < rowBytes ||
        pixels_length < static_cast<size_t>(stride * (height - 1) + rowBytes))
      return encode({});

    // List<ZxingFormat> arrives as a plain [4B count][8B value…] payload
    // (nitro's RecordWriter.encodeList), not the offset-indexed record layout.
    std::vector<BarcodeFormat> wanted;
    NitroRecordReader in(formats);
    for (int32_t i = 0, n = in.readInt32(); i < n; i++)
      if (const int64_t f = in.readInt(); f >= 0 && f < kFormatCount) wanted.push_back(kFormats[f]);
    if (wanted.empty()) wanted.assign(std::begin(kFormats), std::end(kFormats));  // empty = every format

    const ZXing::ImageView image(pixels, static_cast<int>(width), static_cast<int>(height), imageFormat,
                                 static_cast<int>(stride));
    const uint64_t call = calls_.fetch_add(1, std::memory_order_relaxed);

    ZXing::ReaderOptions opts;
    opts.setFormats(ZXing::BarcodeFormats(std::move(wanted)));
    opts.setTryHarder(!live);
    opts.setTryInvert(!live);
    opts.setTryRotate(!live);
    opts.setTryDownscale(!live);
    opts.setMaxNumberOfSymbols(maxSymbols > 0 && maxSymbols < kMaxSymbols ? static_cast<int>(maxSymbols) : kMaxSymbols);

    auto hits = ZXing::ReadBarcodes(image, opts);
    if (hits.empty() && live && call % kRotationPeriod == 0) {
      opts.setTryRotate(true);
      hits = ZXing::ReadBarcodes(image, opts);
    }

    std::vector<ZxingResult> results;
    results.reserve(hits.size());
    for (const auto& hit : hits) {
      const int64_t format = formatOf(hit);
      if (format < 0) continue;
      std::vector<int64_t> corners;
      corners.reserve(8);
      for (const auto& p : hit.position()) {
        corners.push_back(p.x);
        corners.push_back(p.y);
      }
      results.push_back(ZxingResult{hit.text(), static_cast<ZxingFormat>(format), std::move(corners)});
    }
    return encode(results);
  }

 private:
  std::atomic<uint64_t> calls_{0};
};

// Registered when the library loads; one stateless-but-for-a-counter decoder
// serves every isolate (ReadBarcode is reentrant).
NitroZxingImpl g_impl;
struct Registrar {
  Registrar() { nitro_zxing_register_impl(&g_impl); }
} g_registrar;

}  // namespace
