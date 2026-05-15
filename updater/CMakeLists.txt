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

FetchContent_Declare(
    nlohmann_json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG v3.11.3
)
set(JSON_BuildTests OFF CACHE INTERNAL "")
FetchContent_MakeAvailable(nlohmann_json)

# Core library — all the orchestration, state machine, and FFI live here.
set(DASHPOD_UPDATER_SOURCES
    src/util/logging.cpp
    src/util/time.cpp
    src/core/yaml.cpp
    src/core/config.cpp
    src/core/updater_lock.cpp
    src/core/updater.cpp
    src/cache/disk_io.cpp
    src/cache/signing.cpp
    src/cache/lifecycle.cpp
    src/cache/updater_state.cpp
    src/net/network.cpp
    src/net/events.cpp
    src/io/c_file.cpp
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
target_link_libraries(dashpod_updater_obj PUBLIC nlohmann_json::nlohmann_json)
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

option(DASHPOD_UPDATER_BUILD_TESTS "Build tests" OFF)
if(DASHPOD_UPDATER_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
