// Assert-based check of the nitro_zxing decoder through the generated interface.
// Run from the package root:
//   cmake -S src -B build/host && cmake --build build/host
//   clang++ -std=c++20 -Ilib/src/generated/cpp -Isrc -Isrc/native test/native/decode_check.cpp \
//     -Lbuild/host -lnitro_zxing -Wl,-rpath,build/host -o build/decode_check
//   build/decode_check test/native/qr_nitro_256_stride272.luma
#include "nitro_zxing.native.g.h"
#include <cassert>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <vector>

static std::vector<ZxingResult> decode(const std::vector<uint8_t>& px, int w, int h, int stride,
                                       std::vector<ZxingFormat> formats) {
  // The bridge hands the impl the options payload without its 4-byte length prefix.
  auto opts = ZxingReadOptions{std::move(formats), false, false, false, false, false, ZXINGBINARIZER_LOCAL_AVERAGE,
                               ZXINGTEXTMODE_HRI, 0, true, 0, 0, 0, 0}
                  .toNativeBuffer();
  auto buf = nitro_zxing_get_impl()->readBarcodes(px.data(), px.size(), w, h, stride, ZXINGPIXELFORMAT_LUMA,
                                                  {opts.data + 4, opts.size - 4});
  free((void*)opts.data);
  NitroRecordReader r(buf.data + 4, buf.size - 4);
  auto results = r.readIndexedList<ZxingResult>([](NitroRecordReader& r) { return ZxingResult::fromReader(r); });
  free((void*)buf.data);
  return results;
}

int main(int, char** argv) {
  std::ifstream file(argv[1], std::ios::binary);
  std::vector<uint8_t> px((std::istreambuf_iterator<char>(file)), {});
  auto hits = decode(px, 256, 256, 272, {ZXINGFORMAT_QR_CODE});
  assert(hits.size() == 1);
  std::printf("text='%s' format=%d corners=%zu\n", hits[0].text.c_str(), (int)hits[0].format, hits[0].corners.size());
  assert(hits[0].text == "https://nitro.shreeman.dev" && hits[0].format == ZXINGFORMAT_QR_CODE && hits[0].corners.size() == 8);
  assert(decode(px, 256, 256, 272, {}).size() == 1);                     // empty = every format
  assert(decode(px, 256, 256, 272, {ZXINGFORMAT_CODE128}).empty());      // Code 128 only: no QR
  std::vector<uint8_t> blank(272 * 256, 200);
  assert(decode(blank, 256, 256, 272, {}).empty());                      // nothing to find
  assert(decode({1, 2, 3}, 256, 256, 272, {}).empty());                  // short buffer rejected
  std::puts("ok");
}
