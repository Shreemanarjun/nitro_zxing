// nitro_zxing — zxing-cpp reading and writing behind the generated
// HybridNitroZxing interface. Live ladder after react-native-nitro-zxing (MIT,
// Marc Rousavy): a plain scan every call, and a rotation-tolerant scan on
// every 4th call that the plain scan missed.

#include "nitro_zxing.native.g.h"

#include "BitMatrix.h"
#include "MultiFormatWriter.h"
#include "ReadBarcode.h"

// Image file decoding and PNG output, from memory only.
#define STBI_NO_STDIO
#define STB_IMAGE_IMPLEMENTATION
#include "stb/stb_image.h"
#define STBI_WRITE_NO_STDIO
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb/stb_image_write.h"

#include <atomic>
#include <cstdlib>
#include <cstring>
#include <iterator>
#include <memory>
#include <stdexcept>
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

// Indexed by the generated ZxingBinarizer / ZxingTextMode enums.
constexpr ZXing::Binarizer kBinarizers[] = {ZXing::Binarizer::LocalAverage, ZXing::Binarizer::GlobalHistogram,
                                            ZXing::Binarizer::FixedThreshold, ZXing::Binarizer::BoolCast};
constexpr ZXing::TextMode kTextModes[] = {ZXing::TextMode::Plain, ZXing::TextMode::ECI, ZXing::TextMode::HRI,
                                          ZXing::TextMode::Escaped, ZXing::TextMode::Hex};

constexpr uint64_t kRotationPeriod = 4;
constexpr int kMaxSymbols = 255;  // zxing-cpp's own cap

template <typename T, size_t N>
T pick(const T (&table)[N], int64_t i, T fallback) {
  return i >= 0 && i < static_cast<int64_t>(N) ? table[i] : fallback;
}

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
                              int64_t rowStride, ZxingPixelFormat pixelFormat, NitroCppBuffer options) override {
    if (pixelFormat < 0 || pixelFormat >= static_cast<int>(std::size(kPixelFormats))) return encode({});
    const auto [imageFormat, bpp] = kPixelFormats[pixelFormat];
    const int64_t rowBytes = width * bpp;
    const int64_t stride = rowStride > 0 ? rowStride : rowBytes;
    if (!pixels || width <= 0 || height <= 0 || stride < rowBytes ||
        pixels_length < static_cast<size_t>(stride * (height - 1) + rowBytes))
      return encode({});
    return read(ZXing::ImageView(pixels, static_cast<int>(width), static_cast<int>(height), imageFormat,
                                 static_cast<int>(stride)),
                ZxingReadOptions::fromNative(options));
  }

  NitroCppBuffer readBarcodesFromImage(const uint8_t* encoded, size_t encoded_length,
                                       NitroCppBuffer options) override {
    int w = 0, h = 0, channels = 0;
    std::unique_ptr<stbi_uc, void (*)(void*)> pixels(
        encoded ? stbi_load_from_memory(encoded, static_cast<int>(encoded_length), &w, &h, &channels, 1) : nullptr,
        stbi_image_free);
    if (!pixels) return encode({});
    return read(ZXing::ImageView(pixels.get(), w, h, ZXing::ImageFormat::Lum), ZxingReadOptions::fromNative(options));
  }

  NitroCppBuffer writeBarcode(const std::string& text, ZxingFormat format, int64_t width, int64_t height,
                              int64_t margin, int64_t ecLevel) override {
    if (format < 0 || format >= kFormatCount || kFormats[format] == BarcodeFormat::MicroQRCode)
      throw std::invalid_argument("nitro_zxing: writing this format is not supported");
    // Legacy writers (deprecated upstream for the libzint-based API, which
    // nitro_zxing doesn't bundle).
#if defined(_MSC_VER)
#pragma warning(suppress : 4996)
#else
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
    ZXing::MultiFormatWriter writer(kFormats[format]);
#if !defined(_MSC_VER)
#pragma GCC diagnostic pop
#endif
    writer.setMargin(static_cast<int>(margin));
    if (ecLevel >= 0) writer.setEccLevel(static_cast<int>(ecLevel));
    const auto matrix = ZXing::ToMatrix<uint8_t>(
        writer.encode(text, static_cast<int>(std::max<int64_t>(width, 0)), static_cast<int>(std::max<int64_t>(height, 0))));
    return ZxingImage{matrix.width(), matrix.height(), std::vector<uint8_t>(matrix.begin(), matrix.end())}
        .toNativeBuffer();
  }

  NitroCppBuffer lumaToPng(const uint8_t* pixels, size_t pixels_length, int64_t width, int64_t height) override {
    if (!pixels || width <= 0 || height <= 0 || pixels_length < static_cast<size_t>(width * height))
      throw std::invalid_argument("nitro_zxing: lumaToPng needs width*height luma bytes");
    std::vector<uint8_t> png;
    stbi_write_png_to_func(
        [](void* ctx, void* data, int size) {
          auto* out = static_cast<std::vector<uint8_t>*>(ctx);
          out->insert(out->end(), static_cast<uint8_t*>(data), static_cast<uint8_t*>(data) + size);
        },
        &png, static_cast<int>(width), static_cast<int>(height), 1, pixels, static_cast<int>(width));
    // @zeroCopy return: a malloc'd buffer the bridge frees once Dart drops it.
    auto* out = static_cast<uint8_t*>(std::malloc(png.size()));
    std::memcpy(out, png.data(), png.size());
    return {out, png.size()};
  }

 private:
  NitroCppBuffer read(ZXing::ImageView image, const ZxingReadOptions& o) {
    // Region of interest: crop the view in place (no copy), shift corners back.
    const bool cropped = o.regionWidth > 0 && o.regionHeight > 0;
    if (cropped) {
      if (o.regionLeft < 0 || o.regionTop < 0 || o.regionLeft + o.regionWidth > image.width() ||
          o.regionTop + o.regionHeight > image.height())
        return encode({});
      image = image.cropped(static_cast<int>(o.regionLeft), static_cast<int>(o.regionTop),
                            static_cast<int>(o.regionWidth), static_cast<int>(o.regionHeight));
    }

    std::vector<BarcodeFormat> wanted;
    for (const auto f : o.formats)
      if (f >= 0 && f < kFormatCount) wanted.push_back(kFormats[f]);
    if (wanted.empty()) wanted.assign(std::begin(kFormats), std::end(kFormats));  // empty = every format

    ZXing::ReaderOptions opts;
    opts.setFormats(ZXing::BarcodeFormats(std::move(wanted)));
    opts.setTryHarder(o.tryHarder);
    opts.setTryInvert(o.tryInvert);
    opts.setTryRotate(o.tryRotate);
    opts.setTryDownscale(o.tryDownscale);
    opts.setIsPure(o.isPure);
    opts.setBinarizer(pick(kBinarizers, o.binarizer, ZXing::Binarizer::LocalAverage));
    opts.setTextMode(pick(kTextModes, o.textMode, ZXing::TextMode::HRI));
    opts.setMaxNumberOfSymbols(o.maxSymbols > 0 && o.maxSymbols < kMaxSymbols ? static_cast<int>(o.maxSymbols)
                                                                                 : kMaxSymbols);

    const uint64_t call = calls_.fetch_add(1, std::memory_order_relaxed);
    auto hits = ZXing::ReadBarcodes(image, opts);
    if (hits.empty() && o.live && !o.tryRotate && call % kRotationPeriod == 0) {
      opts.setTryRotate(true);
      hits = ZXing::ReadBarcodes(image, opts);
    }

    const int64_t dx = cropped ? o.regionLeft : 0, dy = cropped ? o.regionTop : 0;
    std::vector<ZxingResult> results;
    results.reserve(hits.size());
    for (const auto& hit : hits) {
      const int64_t format = formatOf(hit);
      if (format < 0) continue;
      std::vector<int64_t> corners;
      corners.reserve(8);
      for (const auto& p : hit.position()) {
        corners.push_back(p.x + dx);
        corners.push_back(p.y + dy);
      }
      results.push_back(ZxingResult{
          hit.text(), static_cast<ZxingFormat>(format), std::move(corners), hit.bytes(),
          static_cast<ZxingContentType>(hit.contentType()), hit.orientation(), hit.isMirrored(), hit.isInverted(),
          hit.ecLevel(), hit.symbologyIdentifier()});
    }
    return encode(results);
  }

  std::atomic<uint64_t> calls_{0};
};

// Registered when the library loads; one stateless-but-for-a-counter decoder
// serves every isolate (ReadBarcodes is reentrant).
NitroZxingImpl g_impl;
struct Registrar {
  Registrar() {
    // Barcode images are blocky black/white: no row filter + the fastest zlib
    // level encodes ~2x faster than stb's default (every filter tried, level
    // 8) and decodes faster too, for ~2.5 KB instead of ~1.5 KB per 256x256
    // PNG. Set once: these are globals.
    stbi_write_force_png_filter = 0;
    stbi_write_png_compression_level = 1;
    nitro_zxing_register_impl(&g_impl);
  }
} g_registrar;

}  // namespace
