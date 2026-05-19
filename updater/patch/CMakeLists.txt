# dashpod_patch — C++ port of the Rust `patch` crate (Shorebird upstream).
#
# Produces binary patches in the same bipatch+zstd wire format the updater
# consumes via dashpod::core::inflate_patch. Built as a subdirectory of the
# parent updater/ CMake project; relies on the parent's libzstd_static and
# OpenSSL targets.

# Library — pure encoder. No external surface beyond <dashpod_patch/patch.h>.
add_library(dashpod_patch STATIC
    src/make_patch.cpp
)
target_include_directories(dashpod_patch
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)
target_link_libraries(dashpod_patch PUBLIC
    libzstd_static
)
set_target_properties(dashpod_patch PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)
add_library(dashpod::patch ALIAS dashpod_patch)

# CLI: file-based  →  patch <base> <new> <output>
add_executable(patch src/patch_main.cpp)
target_link_libraries(patch PRIVATE dashpod_patch)

# CLI: string-based  →  string_patch <base> <new>
# Depends on OpenSSL for the SHA-256 hash of `new`, used to generate
# test expectations for the updater.
add_executable(string_patch src/string_patch_main.cpp)
target_link_libraries(string_patch PRIVATE
    dashpod_patch
    OpenSSL::Crypto
)
