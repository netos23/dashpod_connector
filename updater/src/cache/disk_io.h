#pragma once

#include <filesystem>
#include <nlohmann/json.hpp>

namespace dashpod::disk_io {

// Atomically writes `value` to `path` by serialising to JSON in a
// sibling .tmp file and renaming it into place. Creates parent
// directories as needed. Surfaces flush errors that ofstream's
// destructor would silently drop.
//
// Throws UpdaterError on any failure.
void write_json(const nlohmann::json& value, const std::filesystem::path& path);

// Reads JSON from `path`. Throws UpdaterError if the file is missing,
// unreadable, or contains malformed JSON.
nlohmann::json read_json(const std::filesystem::path& path);

// True iff `path` refers to an existing regular file.
bool file_exists(const std::filesystem::path& path);

}  // namespace dashpod::disk_io
