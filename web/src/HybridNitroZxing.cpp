// HybridNitroZxing — web (WASM) implementation. Seeded once by nitrogen link
// from lib/src/generated/cpp/nitro_zxing.impl.g.cpp; never overwritten.
//
// TODO: implement all pure-virtual methods declared in HybridNitroZxing
//   While the line above exists, web keeps compiling the shared
//   src/HybridNitroZxing.cpp. Implement the methods, delete that line, and
//   re-run `nitrogen link` to build the module from this file instead.
//   The module is single-threaded: never block; post async results from
//   emscripten_async_call or a JS callback, not from a std::thread.
//
// Ownership conventions:
//   • Record/variant/tuple RETURNS, **emit_* stream items**, and record/
//     variant CALLBACK arguments you invoke a callback with: pass
//     writer.toNativeBuffer() (or nitro_<Variant>_to_native) — a malloc'd
//     [4B len][payload] block whose ownership transfers to the bridge/Dart.
//     Returning or emitting a non-owning writer.toBuffer() view is wrong:
//     Dart would decode-and-free a live local buffer.
//   • Record/variant PARAMS are non-owning payload views (no length prefix)
//     — copy if you need them after the call.
//   • @HybridStruct RETURNS: the bridge deep-copies every pointer field
//     (String, typed data, nested struct) before Dart sees it, so return
//     views of your own storage (or the argument) and keep ownership of
//     what you return; do not malloc fields for Dart to free.
//   • TypedData RETURNS use NitroCppBuffer{ data, size } where size is in
//     BYTES, not elements (Float32List: count * sizeof(float)). A wrong
//     unit silently truncates the list Dart sees (bytes / elemSize).
//   • @zeroCopy TypedData returns are NOT copied by the bridge: return a
//     malloc'd buffer — ownership transfers, and the bridge frees it (via
//     <lib>_release_typed_data_return) when Dart's view is GC'd. Never
//     return a pointer to a member or stack buffer: it would be free()d.

#include "nitro_zxing.native.g.h"
#include <stdexcept>

// ── Implementation ───────────────────────────────────────────────────────────

class NitroZxingImpl final : public HybridNitroZxing {
public:
    NitroZxingImpl() = default;
    ~NitroZxingImpl() override = default;

    // ── Methods ──────────────────────────────────────────────────────────────

    NitroCppBuffer decodeLuma(const uint8_t* luma, size_t luma_length, int64_t width, int64_t height, int64_t rowStride, int64_t formats, bool live) override {
        // TODO: implement decodeLuma
        throw std::runtime_error("Not implemented: decodeLuma");
        // return { nullptr, 0 };
    }
};

// ── Registration ─────────────────────────────────────────────────────────────
//
// Create a single instance and register it during plugin/app initialisation:
//
//   static NitroZxingImpl g_impl;
//   nitro_zxing_register_impl(&g_impl);   // in your plugin init
//   nitro_zxing_register_impl(nullptr);   // in your plugin dispose
//
// On Flutter desktop (Windows / Linux / macOS with NativeImpl.cpp) add the
// registration call to your Flutter plugin's RegisterWithRegistrar:
//
//   void NitroZxingPlugin::RegisterWithRegistrar(PluginRegistrar* registrar) {
//       static NitroZxingImpl impl;
//       nitro_zxing_register_impl(&impl);
//   }

// Registered when the wasm module instantiates.
namespace {
  struct _AutoRegister {
    _AutoRegister() { nitro_zxing_register_impl(new NitroZxingImpl()); }
  };
  static _AutoRegister _auto_register_instance;
}
