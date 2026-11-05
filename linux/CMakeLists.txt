set(NITRO_NATIVE "${CMAKE_CURRENT_SOURCE_DIR}/../src/native")

# The Flutter tooling requires CMake 3.10 or later; do not raise it.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "nitro_zxing")
project(${PROJECT_NAME} LANGUAGES C CXX)

# Shared build (zxing-cpp + src/HybridNitroZxing.cpp), same as Android.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(nitro_zxing_bundled_libraries
  $<TARGET_FILE:nitro_zxing>
  PARENT_SCOPE
)
