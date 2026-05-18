#include "net/network.h"

#include <fstream>
#include <system_error>

#ifndef CPPHTTPLIB_OPENSSL_SUPPORT
#define CPPHTTPLIB_OPENSSL_SUPPORT
#endif
#include <httplib.h>

#include "core/config.h"
#include "core/error.h"
#include "util/logging.h"

namespace fs = std::filesystem;

namespace dashpod::net {

// ---------------- JSON conversions ----------------

nlohmann::json patch_to_json(const Patch& p) {
    nlohmann::json j;
    j["number"]       = p.number;
    j["hash"]         = p.hash;
    j["download_url"] = p.download_url;
    if (p.hash_signature.has_value()) {
        j["hash_signature"] = *p.hash_signature;
    } else {
        j["hash_signature"] = nullptr;
    }
    return j;
}

Patch patch_from_json(const nlohmann::json& j) {
    Patch p;
    p.number       = j.at("number").get<std::size_t>();
    p.hash         = j.at("hash").get<std::string>();
    p.download_url = j.at("download_url").get<std::string>();
    if (j.contains("hash_signature") && !j.at("hash_signature").is_null()) {
        p.hash_signature = j.at("hash_signature").get<std::string>();
    }
    return p;
}

PatchCheckRequest PatchCheckRequest::from_config(
    const core::UpdateConfig& cfg,
    const std::string& client_id,
    std::optional<std::size_t> current_patch_number) {
    return PatchCheckRequest{
        cfg.app_id,
        cfg.channel,
        cfg.release_version,
        core::current_platform(),
        core::current_arch(),
        client_id,
        current_patch_number,
    };
}

nlohmann::json patch_check_request_to_json(const PatchCheckRequest& r) {
    nlohmann::json j;
    j["app_id"]          = r.app_id;
    j["channel"]         = r.channel;
    j["release_version"] = r.release_version;
    j["platform"]        = r.platform;
    j["arch"]            = r.arch;
    j["client_id"]       = r.client_id;
    // Omit (not null) when absent — matches the wire contract.
    if (r.current_patch_number.has_value()) {
        j["current_patch_number"] = *r.current_patch_number;
    }
    return j;
}

PatchCheckResponse patch_check_response_from_json(const nlohmann::json& j) {
    PatchCheckResponse r;
    r.patch_available = j.value("patch_available", false);
    if (j.contains("patch") && !j.at("patch").is_null()) {
        r.patch = patch_from_json(j.at("patch"));
    }
    if (j.contains("rolled_back_patch_numbers") &&
        !j.at("rolled_back_patch_numbers").is_null()) {
        r.rolled_back_patch_numbers =
            j.at("rolled_back_patch_numbers").get<std::vector<std::size_t>>();
    }
    return r;
}

std::string patches_check_url(const std::string& base_url) {
    return base_url + "/api/v1/patches/check";
}

std::string patches_events_url(const std::string& base_url) {
    return base_url + "/api/v1/patches/events";
}

// ---------------- HTTP helpers ----------------

namespace {

// Splits "https://host/path" into ("https://host", "/path").
std::pair<std::string, std::string> split_url(const std::string& url) {
    auto sep = url.find("://");
    if (sep == std::string::npos) return {"http://localhost", url};
    auto after = sep + 3;
    auto slash = url.find('/', after);
    if (slash == std::string::npos) return {url, "/"};
    return {url.substr(0, slash), url.substr(slash)};
}

// Configures timeouts common to every client instance.
void configure(httplib::Client& cli) {
    cli.set_connection_timeout(10);
    cli.set_read_timeout(300);
    cli.set_write_timeout(30);
}

// ---- Default NetworkHooks implementations ----

PatchCheckResponse real_patch_check_request(const std::string& url,
                                              const PatchCheckRequest& req) {
    auto [base, path] = split_url(url);
    httplib::Client cli(base);
    configure(cli);

    auto body = patch_check_request_to_json(req).dump();
    DASHPOD_INFO("POST ", url);
    auto res = cli.Post(path, body, "application/json");
    if (!res) {
        throw UpdaterError(UpdaterError::Kind::Network,
            "Patch check failed (error=" +
            std::to_string(static_cast<int>(res.error())) + ")");
    }
    if (res->status != 200) {
        throw UpdaterError(UpdaterError::Kind::BadServerResponse,
            "Patch check returned HTTP " + std::to_string(res->status));
    }
    try {
        auto j = nlohmann::json::parse(res->body);
        return patch_check_response_from_json(j);
    } catch (const nlohmann::json::exception& e) {
        throw UpdaterError(UpdaterError::Kind::BadServerResponse,
            std::string("Patch check: malformed JSON: ") + e.what());
    }
}

DownloadResult real_download_to_path(const std::string& url,
                                      const fs::path& dest,
                                      std::uint64_t resume_from) {
    auto [base, path] = split_url(url);
    httplib::Client cli(base);
    configure(cli);

    // Open the output file.  On resume we append; on fresh start we truncate.
    auto open_mode = (resume_from > 0)
        ? (std::ios::binary | std::ios::app)
        : (std::ios::binary | std::ios::trunc);
    std::ofstream out(dest, open_mode);
    if (!out) {
        throw UpdaterError(UpdaterError::Kind::Io,
            "Cannot open " + dest.string() + " for writing");
    }

    DownloadResult result;
    std::uint64_t written = 0;

    httplib::Headers headers;
    if (resume_from > 0) {
        headers.insert({"Range", "bytes=" + std::to_string(resume_from) + "-"});
    }

    bool response_ok = false;

    auto response_handler = [&](const httplib::Response& resp) -> bool {
        if (resp.status == 200 && resume_from > 0) {
            // Server ignored the Range header — restart from scratch.
            out.close();
            out.open(dest, std::ios::binary | std::ios::trunc);
            if (!out) return false;
        } else if (resp.status == 206) {
            // Parse Content-Range: bytes START-END/TOTAL
            auto cr = resp.get_header_value("Content-Range");
            auto slash = cr.rfind('/');
            if (slash != std::string::npos) {
                try {
                    result.content_length = std::stoull(cr.substr(slash + 1));
                } catch (...) {}
            }
        } else if (resp.status == 200) {
            auto cl = resp.get_header_value("Content-Length");
            if (!cl.empty()) {
                try { result.content_length = std::stoull(cl); } catch (...) {}
            }
        } else {
            DASHPOD_ERROR("Download returned HTTP ", resp.status, " for ", url);
            return false;
        }
        response_ok = true;
        return true;
    };

    auto content_receiver = [&](const char* data, size_t len) -> bool {
        out.write(data, static_cast<std::streamsize>(len));
        if (!out) return false;
        written += len;
        return true;
    };

    DASHPOD_INFO("GET ", url, (resume_from ? " (resume from " + std::to_string(resume_from) + ")" : ""));
    auto res = cli.Get(path, headers, response_handler, content_receiver);
    if (!res || !response_ok) {
        throw UpdaterError(UpdaterError::Kind::Network,
            "Download failed (url=" + url + " error=" +
            std::to_string(static_cast<int>(res.error())) + ")");
    }

    result.total_bytes = written;
    return result;
}

void real_report_event(const std::string& url, const PatchEvent& event) {
    auto [base, path] = split_url(url);
    httplib::Client cli(base);
    configure(cli);

    nlohmann::json body_json;
    body_json["event"] = patch_event_to_json(event);
    auto body = body_json.dump();
    DASHPOD_INFO("POST event ", url);
    auto res = cli.Post(path, body, "application/json");
    if (!res) {
        throw UpdaterError(UpdaterError::Kind::Network,
            "Event report failed (error=" +
            std::to_string(static_cast<int>(res.error())) + ")");
    }
    // 200, 201, 202 are all acceptable.
    if (res->status < 200 || res->status > 299) {
        throw UpdaterError(UpdaterError::Kind::BadServerResponse,
            "Event report returned HTTP " + std::to_string(res->status));
    }
}

}  // namespace

// ---------------- NetworkHooks ----------------

NetworkHooks::NetworkHooks()
    : patch_check_request_fn(real_patch_check_request),
      download_to_path_fn(real_download_to_path),
      report_event_fn(real_report_event) {}

// ---------------- Helpers called by the orchestrator ----------------

DownloadResult download_to_path(const NetworkHooks& hooks,
                                 const std::string& url,
                                 const fs::path& path,
                                 std::uint64_t resume_from) {
    DASHPOD_INFO("Downloading patch from: ", url);
    if (path.has_parent_path()) {
        std::error_code ec;
        fs::create_directories(path.parent_path(), ec);
        if (ec) {
            throw UpdaterError(UpdaterError::Kind::Io,
                "Failed to create download dir: " + ec.message());
        }
    }
    auto result = hooks.download_to_path_fn(url, path, resume_from);
    DASHPOD_INFO("Downloaded ", result.total_bytes, " bytes to ", path.string());
    return result;
}

void send_patch_event(const PatchEvent& event,
                       const core::UpdateConfig& config) {
    if (!config.network_hooks) {
        throw UpdaterError(UpdaterError::Kind::Network, "No network hooks");
    }
    config.network_hooks->report_event_fn(
        patches_events_url(config.base_url), event);
}

}  // namespace dashpod::net