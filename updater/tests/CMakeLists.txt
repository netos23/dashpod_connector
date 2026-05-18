include(FetchContent)

FetchContent_Declare(Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.6.0
    GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(Catch2)

add_executable(dashpod_updater_tests
    test_signing.cpp
    test_network.cpp
    test_inflate.cpp
    test_lifecycle.cpp
    test_android.cpp
)

target_include_directories(dashpod_updater_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(dashpod_updater_tests PRIVATE
    dashpod_updater_static
    Catch2::Catch2WithMain
    OpenSSL::Crypto
    OpenSSL::SSL
)

add_test(NAME dashpod_updater_tests COMMAND dashpod_updater_tests)
