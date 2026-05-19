cmake_minimum_required(VERSION 3.20)
project(dashpod_updater LANGUAGES CXX VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "" FORCE)
endif()

if(MSVC)
    add_compile_options(/W4 /permissive-)
else()
    add_compile_options(-Wall -Wextra -Wpedantic -Wno-unused-parameter)
endif()

include(FetchContent)
set(FETCHCONTENT_QUIET ON)

# nlohmann/json
FetchContent_Declare(
    nlohmann_json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG v3.11.3
)
set(JSON_BuildTests OFF CACHE INTERNAL "")
FetchContent_MakeAvailable(nlohmann_json)

# OpenSSL — RSA-PKCS1v1.5 signing + HTTPS transport
if(APPLE AND NOT DEFINED OPENSSL_ROOT_DIR)
    execute_process(COMMAND brew --prefix openssl@3
        OUTPUT_VARIABLE BREW_OPENSSL
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
    if(BREW_OPENSSL)
        set(OPENSSL_ROOT_DIR "${BREW_OPENSSL}" CACHE PATH "Homebrew OpenSSL root")
    endif()
endif()
find_package(OpenSSL REQUIRED)

# cpp-httplib — header-only HTTPS client (OpenSSL backend)
FetchContent_Declare(httplib
    GIT_REPOSITORY https://github.com/yhirose/cpp-httplib.git
    GIT_TAG v0.18.3
    GIT_SHALLOW TRUE)
set(HTTPLIB_USE_OPENSSL_IF_AVAILABLE ON CACHE BOOL "" FORCE)
set(HTTPLIB_COMPILE OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(httplib)

# zstd — patch decompression
FetchContent_Declare(zstd_fetch
    GIT_REPOSITORY https://github.com/facebook/zstd.git
    GIT_TAG v1.5.6
    GIT_SHALLOW TRUE
    SOURCE_SUBDIR build/cmake)
set(ZSTD_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_TESTS  OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(zstd_fetch)

# zlib — for DEFLATE decompression of APK entries (system library on macOS,
# Linux, and Android NDK; required on Android, optional elsewhere for tests).
if(ANDROID)
    find_package(ZLIB REQUIRED)
else()
    find_package(ZLIB)
endif()

# Core library — all orchestration, state machine, and FFI live here.
set(DASHPOD_UPDATER_SOURCES
    src/util/logging.cpp
    src/util/time.cpp
    src/core/yaml.cpp
    src/core/config.cpp
    src/core/updater_lock.cpp
    src/core/updater.cpp
    src/core/inflate.cpp
    src/cache/disk_io.cpp
    src/cache/signing.cpp
    src/cache/lifecycle.cpp
    src/cache/updater_state.cpp
    src/net/network.cpp
    src/net/events.cpp
    src/io/c_file.cpp
    src/platform/android.cpp
    src/api/common.cpp
    src/api/engine.cpp
    src/api/dart.cpp
)

add_library(dashpod_updater_obj OBJECT ${DASHPOD_UPDATER_SOURCES})
target_include_directories(dashpod_updater_obj
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)
# CPPHTTPLIB_OPENSSL_SUPPORT is forwarded by httplib::httplib when OpenSSL is
# found; the explicit define here is a belt-and-suspenders guard.
target_compile_definitions(dashpod_updater_obj PRIVATE
    CPPHTTPLIB_OPENSSL_SUPPORT
)
target_link_libraries(dashpod_updater_obj PUBLIC
    nlohmann_json::nlohmann_json
    OpenSSL::Crypto
    OpenSSL::SSL
    httplib::httplib
    libzstd_static
)
if(ZLIB_FOUND)
    target_compile_definitions(dashpod_updater_obj PRIVATE DASHPOD_HAVE_ZLIB)
    target_link_libraries(dashpod_updater_obj PUBLIC ZLIB::ZLIB)
endif()
set_target_properties(dashpod_updater_obj PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# Static archive (mirrors Rust `staticlib` — link into a host binary).
add_library(dashpod_updater_static STATIC $<TARGET_OBJECTS:dashpod_updater_obj>)
target_link_libraries(dashpod_updater_static PUBLIC dashpod_updater_obj)
set_target_properties(dashpod_updater_static PROPERTIES
    OUTPUT_NAME dashpod_updater
)

# Shared library (mirrors Rust `cdylib` — for Dart FFI / dlopen consumers).
add_library(dashpod_updater_shared SHARED $<TARGET_OBJECTS:dashpod_updater_obj>)
target_link_libraries(dashpod_updater_shared PUBLIC dashpod_updater_obj)
set_target_properties(dashpod_updater_shared PROPERTIES
    OUTPUT_NAME dashpod_updater
)

# Convenience alias so consumers can `target_link_libraries(... dashpod::updater)`.
add_library(dashpod::updater ALIAS dashpod_updater_static)

# Smoke-test executable. Keeps the original `updater` target name from
# the CLion-generated skeleton so existing IDE run configs still work.
add_executable(updater tests/main.cpp)
target_link_libraries(updater PRIVATE dashpod_updater_static)

# Sibling package: bipatch+zstd encoder + `patch`/`string_patch` CLIs.
# Lives in patch/ and reuses libzstd_static + OpenSSL from this scope.
add_subdirectory(patch)

option(DASHPOD_UPDATER_BUILD_TESTS "Build Catch2 unit tests" OFF)
if(DASHPOD_UPDATER_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()