// Assert-based check of the nitro_zxing decoder through the generated interface.
// Run from the package root:
//   cmake -S src -B build/host && cmake --build build/host
//   clang++ -std=c++20 -Ilib/src/generated/cpp -Isrc -Isrc/native test/native/decode_check.cpp \
//     -Lbuild/host -lnitro_zxing -Wl,-rpath,build/host -o build/decode_check
//   build/decode_check test/native/qr_margelo_256_stride272.luma
#include "nitro_zxing.native.g.h"
#include <cassert>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <vector>

static ZxingResult decode(const std::vector<uint8_t>& px, int w, int h, int stride, int64_t formats) {
  auto buf = nitro_zxing_get_impl()->decodeLuma(px.data(), px.size(), w, h, stride, formats, true);
  auto r = ZxingResult::fromNative({buf.data + 4, buf.size - 4});
  free((void*)buf.data);
  return r;
}

int main(int, char** argv) {
  std::ifstream f(argv[1], std::ios::binary);
  std::vector<uint8_t> px((std::istreambuf_iterator<char>(f)), {});
  auto hit = decode(px, 256, 256, 272, 1);  // QR only
  std::printf("text='%s' format=%lld corners=%zu\n", hit.text.c_str(), (long long)hit.format, hit.corners.size());
  assert(!hit.text.empty() && hit.format == 1 && hit.corners.size() == 8);
  assert(decode(px, 256, 256, 272, 1 << 4).text.empty());              // Code 128 only: no QR
  std::vector<uint8_t> blank(272 * 256, 200);
  assert(decode(blank, 256, 256, 272, 1).text.empty());                // nothing to find
  assert(decode(px, 256, 256, 272, 1).text == hit.text);               // repeatable
  assert(decode({1, 2, 3}, 256, 256, 272, 1).text.empty());           // short buffer rejected
  std::puts("ok");
}
