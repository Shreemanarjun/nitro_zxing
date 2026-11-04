cmake_minimum_required(VERSION 3.10)
project(nitro_zxing_library VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Optimization guard ───────────────────────────────────────────────────────
# The Android Gradle Plugin passes the VARIANT name (e.g. "profile") as
# CMAKE_BUILD_TYPE. CMake only defines per-config flags for
# Debug/Release/RelWithDebInfo/MinSizeRel — an unknown config has EMPTY flag
# sets, so every native source silently compiles at -O0. Flutter's release
# variant maps to RELEASE and is unaffected, but profile builds shipped
# unoptimized native code. Give any non-standard config Release-grade flags.
string(TOUPPER "${CMAKE_BUILD_TYPE}" _NITRO_CFG)
if(NOT "${_NITRO_CFG}" MATCHES "^(DEBUG|RELEASE|RELWITHDEBINFO|MINSIZEREL|)$")
  set(CMAKE_C_FLAGS_${_NITRO_CFG} "-O2 -DNDEBUG")
  set(CMAKE_CXX_FLAGS_${_NITRO_CFG} "-O2 -DNDEBUG")
endif()

set(NITRO_NATIVE "${CMAKE_CURRENT_SOURCE_DIR}/native")
# NITRO_LINK_SPEC_CHECKSUM c4b84cc387fd6c1d
set(GENERATED_CPP "${CMAKE_CURRENT_SOURCE_DIR}/../lib/src/generated/cpp")

# zxing-cpp readers only, as a static archive linked into the plugin.
set(ZXING_READERS ON CACHE BOOL "" FORCE)
set(ZXING_WRITERS OFF CACHE STRING "" FORCE)
set(ZXING_C_API OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF)
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/zxing-cpp/core" "${CMAKE_BINARY_DIR}/zxing-cpp" EXCLUDE_FROM_ALL)

add_library(nitro_zxing SHARED
  "HybridNitroZxing.cpp"
  "nitro_zxing.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../lib/src/generated/cpp/nitro_zxing.bridge.g.cpp"
  "dart_api_dl.c"
)

target_include_directories(nitro_zxing PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${GENERATED_CPP}"
  "${NITRO_NATIVE}"
)

target_compile_definitions(nitro_zxing PUBLIC DART_SHARED_LIB)
target_link_libraries(nitro_zxing PRIVATE ZXing::ZXing)

if(ANDROID)
  target_link_libraries(nitro_zxing PRIVATE android log)
  target_link_options(nitro_zxing PRIVATE "-Wl,-z,max-page-size=16384")
endif()
