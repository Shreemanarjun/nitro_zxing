// Assert-based check of the nitro_zxing decoder through the generated interface.
// Run from the package root:
//   cmake -S src -B build/host && cmake --build build/host
//   clang++ -std=c++20 -Ilib/src/generated/cpp -Isrc -Isrc/native test/native/decode_check.cpp \
//     -Lbuild/host -lnitro_zxing -Wl,-rpath,build/host -o build/decode_check
//   build/decode_check test/native/qr_margelo_256_stride272.luma
#include "nitro_zxing.native.g.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <vector>

// formats as nitro sends List<ZxingFormat>: [4B count][8B value…].
static std::vector<ZxingResult> decode(const std::vector<uint8_t>& px, int w, int h, int stride,
                                       std::vector<int64_t> formats) {
  std::vector<uint8_t> f(4 + 8 * formats.size());
  const int32_t n = static_cast<int32_t>(formats.size());
  std::memcpy(f.data(), &n, 4);
  std::memcpy(f.data() + 4, formats.data(), 8 * formats.size());
  auto buf = nitro_zxing_get_impl()->readBarcodes(px.data(), px.size(), w, h, stride, ZXINGPIXELFORMAT_LUMA,
                                                  {f.data(), f.size()}, true, 0);
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
  assert(hits[0].text == "https://margelo.com" && hits[0].format == ZXINGFORMAT_QR_CODE && hits[0].corners.size() == 8);
  assert(decode(px, 256, 256, 272, {}).size() == 1);                     // empty = every format
  assert(decode(px, 256, 256, 272, {ZXINGFORMAT_CODE128}).empty());      // Code 128 only: no QR
  std::vector<uint8_t> blank(272 * 256, 200);
  assert(decode(blank, 256, 256, 272, {}).empty());                      // nothing to find
  assert(decode({1, 2, 3}, 256, 256, 272, {}).empty());                  // short buffer rejected
  std::puts("ok");
}
