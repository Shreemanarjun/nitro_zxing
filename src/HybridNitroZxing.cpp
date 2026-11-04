// nitro_zxing — zxing-cpp decoding behind the generated HybridNitroZxing
// interface. Live ladder after react-native-nitro-zxing (MIT, Marc Rousavy):
// a plain scan every call, and a rotation-tolerant scan on every 4th call
// that the plain scan missed.

#include "nitro_zxing.native.g.h"

#include "ReadBarcode.h"

#include <atomic>
#include <utility>
#include <vector>

namespace {

using ZXing::BarcodeFormat;

// Bit values mirror ZxingFormat in lib/nitro_zxing.dart.
constexpr std::pair<int64_t, BarcodeFormat> kFormats[] = {
    {1 << 0, BarcodeFormat::QRCode},     {1 << 1, BarcodeFormat::Aztec},
    {1 << 2, BarcodeFormat::DataMatrix}, {1 << 3, BarcodeFormat::PDF417},
    {1 << 4, BarcodeFormat::Code128},    {1 << 5, BarcodeFormat::Code39},
    {1 << 6, BarcodeFormat::Code93},     {1 << 7, BarcodeFormat::Codabar},
    {1 << 8, BarcodeFormat::EAN13},      {1 << 9, BarcodeFormat::EAN8},
    {1 << 10, BarcodeFormat::UPCA},      {1 << 11, BarcodeFormat::UPCE},
    {1 << 12, BarcodeFormat::ITF},       {1 << 13, BarcodeFormat::MicroQRCode},
};

constexpr uint64_t kRotationPeriod = 4;

int64_t bitOf(const ZXing::Barcode& b) {
  for (const auto& [bit, f] : kFormats)
    if (b.format() == f || b.symbology() == f) return bit;
  return 0;
}

NitroCppBuffer miss() { return ZxingResult{"", 0, {}}.toNativeBuffer(); }

class NitroZxingImpl final : public HybridNitroZxing {
 public:
  NitroCppBuffer decodeLuma(const uint8_t* luma, size_t luma_length, int64_t width, int64_t height,
                            int64_t rowStride, int64_t formats, bool live) override {
    const int64_t stride = rowStride > 0 ? rowStride : width;
    if (!luma || width <= 0 || height <= 0 || stride < width ||
        luma_length < static_cast<size_t>(stride * (height - 1) + width))
      return miss();

    std::vector<BarcodeFormat> wanted;
    for (const auto& [bit, f] : kFormats)
      if (formats & bit) wanted.push_back(f);
    if (wanted.empty()) return miss();

    const ZXing::ImageView image(luma, static_cast<int>(width), static_cast<int>(height),
                                 ZXing::ImageFormat::Lum, static_cast<int>(stride));
    const uint64_t call = calls_.fetch_add(1, std::memory_order_relaxed);

    ZXing::ReaderOptions opts;
    opts.setFormats(ZXing::BarcodeFormats(std::move(wanted)));
    opts.setTryHarder(!live);
    opts.setTryInvert(!live);
    opts.setTryRotate(!live);
    opts.setTryDownscale(!live);
    opts.setMaxNumberOfSymbols(1);

    auto hit = ZXing::ReadBarcode(image, opts);
    if (!hit.isValid() && live && call % kRotationPeriod == 0) {
      opts.setTryRotate(true);
      hit = ZXing::ReadBarcode(image, opts);
    }
    if (!hit.isValid()) return miss();

    std::vector<int64_t> corners;
    corners.reserve(8);
    for (const auto& p : hit.position()) {
      corners.push_back(p.x);
      corners.push_back(p.y);
    }
    return ZxingResult{hit.text(), bitOf(hit), std::move(corners)}.toNativeBuffer();
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
