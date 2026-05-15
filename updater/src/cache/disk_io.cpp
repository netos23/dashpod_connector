#include "cache/disk_io.h"

#include <fstream>
#include <system_error>

#include "core/error.h"
#include "util/logging.h"

namespace dashpod::disk_io {

namespace {

std::filesystem::path temp_sibling(const std::filesystem::path& path) {
    auto filename = path.filename().string();
    if (filename.empty()) filename = "state";
    return path.parent_path() / (filename + ".tmp");
}

}  // namespace

bool file_exists(const std::filesystem::path& path) {
    std::error_code ec;
    return std::filesystem::is_regular_file(path, ec);
}

void write_json(const nlohmann::json& value, const std::filesystem::path& path) {
    DASHPOD_DEBUG("Writing to ", path.string());

    auto parent = path.parent_path();
    if (!parent.empty()) {
        std::error_code ec;
        std::filesystem::create_directories(parent, ec);
        if (ec) {
            throw UpdaterError(UpdaterError::Kind::Io,
                "Failed to create parent dir " + parent.string() +
                ": " + ec.message());
        }
    }

    const auto tmp = temp_sibling(path);
    {
        std::ofstream out(tmp, std::ios::binary | std::ios::trunc);
        if (!out) {
            throw UpdaterError(UpdaterError::Kind::Io,
                "Failed to create temp file " + tmp.string());
        }
        // pretty-printed JSON, matching the Rust reference's
        // serde_json::to_writer_pretty output.
        const std::string text = value.dump(2);
        out.write(text.data(), static_cast<std::streamsize>(text.size()));
        out.flush();
        if (!out.good()) {
            std::error_code ec;
            std::filesystem::remove(tmp, ec);
            throw UpdaterError(UpdaterError::Kind::Io,
                "Failed to flush " + tmp.string());
        }
        out.close();
        if (!out.good()) {
            std::error_code ec;
            std::filesystem::remove(tmp, ec);
            throw UpdaterError(UpdaterError::Kind::Io,
                "Failed to close " + tmp.string());
        }
    }

    std::error_code ec;
    std::filesystem::rename(tmp, path, ec);
    if (ec) {
        std::filesystem::remove(tmp, ec);
        throw UpdaterError(UpdaterError::Kind::Io,
            "Failed to rename " + tmp.string() + " -> " + path.string() +
            ": " + ec.message());
    }
}

nlohmann::json read_json(const std::filesystem::path& path) {
    DASHPOD_DEBUG("Reading from ", path.string());

    if (!file_exists(path)) {
        throw UpdaterError(UpdaterError::Kind::Io,
            "File " + path.string() + " does not exist");
    }

    std::ifstream in(path, std::ios::binary);
    if (!in) {
        throw UpdaterError(UpdaterError::Kind::Io,
            "Failed to open " + path.string());
    }

    try {
        return nlohmann::json::parse(in);
    } catch (const nlohmann::json::exception& e) {
        throw UpdaterError(UpdaterError::Kind::Io,
            "Failed to deserialize " + path.string() + ": " + e.what());
    }
}

}  // namespace dashpod::disk_io
