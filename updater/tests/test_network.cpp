#include <catch2/catch_test_macros.hpp>

#include <string>
#include <vector>

#include "net/events.h"
#include "net/network.h"

// ---------------------------------------------------------------------------
// JSON serialisation round-trips (no real HTTP)
// ---------------------------------------------------------------------------

TEST_CASE("PatchCheckRequest round-trips through JSON", "[network]") {
    dashpod::net::PatchCheckRequest req;
    req.app_id          = "1234";
    req.channel         = "stable";
    req.release_version = "1.0.0+42";
    req.platform        = "android";
    req.arch            = "aarch64";
    req.client_id       = "5d8e0b3f-43c0-4b6a-9c2f-a7e2c12ec0de";
    req.current_patch_number = 3;

    auto j = dashpod::net::patch_check_request_to_json(req);
    REQUIRE(j["app_id"]          == "1234");
    REQUIRE(j["channel"]         == "stable");
    REQUIRE(j["release_version"] == "1.0.0+42");
    REQUIRE(j["platform"]        == "android");
    REQUIRE(j["arch"]            == "aarch64");
    REQUIRE(j["client_id"]       == "5d8e0b3f-43c0-4b6a-9c2f-a7e2c12ec0de");
    REQUIRE(j["current_patch_number"] == 3);
}

TEST_CASE("PatchCheckRequest omits current_patch_number when absent", "[network]") {
    dashpod::net::PatchCheckRequest req;
    req.app_id = "x"; req.channel = "s"; req.release_version = "1";
    req.platform = "ios"; req.arch = "aarch64"; req.client_id = "u";
    req.current_patch_number = std::nullopt;

    auto j = dashpod::net::patch_check_request_to_json(req);
    REQUIRE(!j.contains("current_patch_number"));
}

TEST_CASE("PatchCheckResponse parses patch_available=false", "[network]") {
    auto j = nlohmann::json::parse(R"({"patch_available": false})");
    auto r = dashpod::net::patch_check_response_from_json(j);
    REQUIRE(r.patch_available == false);
    REQUIRE(!r.patch.has_value());
    REQUIRE(!r.rolled_back_patch_numbers.has_value());
}

TEST_CASE("PatchCheckResponse parses patch and rolled_back_patch_numbers", "[network]") {
    auto j = nlohmann::json::parse(R"({
        "patch_available": true,
        "patch": {
            "number": 2,
            "download_url": "https://cdn.example.com/p/2/dlc.vmcode",
            "hash": "bb8f1d041a5cdc259055afe9617136799543e0a7a86f86db82f8c1fadbd8cc45",
            "hash_signature": null
        },
        "rolled_back_patch_numbers": [1]
    })");
    auto r = dashpod::net::patch_check_response_from_json(j);
    REQUIRE(r.patch_available == true);
    REQUIRE(r.patch.has_value());
    REQUIRE(r.patch->number == 2);
    REQUIRE(r.patch->hash == "bb8f1d041a5cdc259055afe9617136799543e0a7a86f86db82f8c1fadbd8cc45");
    REQUIRE(!r.patch->hash_signature.has_value());
    REQUIRE(r.rolled_back_patch_numbers.has_value());
    REQUIRE(r.rolled_back_patch_numbers->size() == 1);
    REQUIRE((*r.rolled_back_patch_numbers)[0] == 1);
}

TEST_CASE("Patch hash_signature round-trip", "[network]") {
    dashpod::net::Patch p;
    p.number       = 1;
    p.hash         = "aabbcc";
    p.download_url = "https://cdn.example.com/p/1";
    p.hash_signature = "base64sig==";

    auto j  = dashpod::net::patch_to_json(p);
    auto p2 = dashpod::net::patch_from_json(j);
    REQUIRE(p2.hash_signature.has_value());
    REQUIRE(p2.hash_signature.value() == "base64sig==");
}

TEST_CASE("patches_check_url appends correct path", "[network]") {
    REQUIRE(dashpod::net::patches_check_url("https://api.example.com")
            == "https://api.example.com/api/v1/patches/check");
}

TEST_CASE("patches_events_url appends correct path", "[network]") {
    REQUIRE(dashpod::net::patches_events_url("https://api.example.com")
            == "https://api.example.com/api/v1/patches/events");
}

// ---------------------------------------------------------------------------
// Event JSON serialisation
// ---------------------------------------------------------------------------

TEST_CASE("PatchEvent round-trips through JSON", "[network]") {
    dashpod::net::PatchEvent ev;
    ev.app_id          = "app1";
    ev.arch            = "aarch64";
    ev.client_id       = "uuid-here";
    ev.identifier      = dashpod::net::EventType::PatchInstallSuccess;
    ev.patch_number    = 5;
    ev.platform        = "android";
    ev.release_version = "2.0.0+1";
    ev.timestamp       = 1715789012ULL;
    ev.message         = "all good";

    auto j   = dashpod::net::patch_event_to_json(ev);
    auto ev2 = dashpod::net::patch_event_from_json(j);

    REQUIRE(ev2.app_id          == ev.app_id);
    REQUIRE(ev2.identifier      == dashpod::net::EventType::PatchInstallSuccess);
    REQUIRE(ev2.patch_number    == 5);
    REQUIRE(ev2.message.has_value());
    REQUIRE(ev2.message.value() == "all good");
    REQUIRE(j["type"] == "__patch_install__");
}

TEST_CASE("NetworkHooks default constructor is non-null", "[network]") {
    dashpod::net::NetworkHooks hooks;
    REQUIRE(static_cast<bool>(hooks.patch_check_request_fn));
    REQUIRE(static_cast<bool>(hooks.download_to_path_fn));
    REQUIRE(static_cast<bool>(hooks.report_event_fn));
}
