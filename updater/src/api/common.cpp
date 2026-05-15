#include "api/common.h"

#include <cstdlib>
#include <cstring>

#include "core/error.h"
#include "util/logging.h"

namespace dashpod::api {

char* allocate_c_string(const std::string& s) noexcept {
    auto* buf = static_cast<char*>(std::malloc(s.size() + 1));
    if (buf == nullptr) return nullptr;
    std::memcpy(buf, s.data(), s.size());
    buf[s.size()] = '\0';
    return buf;
}

void free_c_string(const char* s) noexcept {
    if (s == nullptr) return;
    std::free(const_cast<char*>(s));
}

std::string to_rust(const char* s) {
    if (s == nullptr) {
        throw UpdaterError(UpdaterError::Kind::InvalidArgument,
                           "Null string passed across FFI");
    }
    return std::string(s);
}

std::optional<std::string> to_rust_option(const char* s) {
    if (s == nullptr) return std::nullopt;
    return std::string(s);
}

void log_error_at_boundary(const char* ctx, const char* what) noexcept {
    try {
        DASHPOD_ERROR("Error ", ctx, ": ", what);
    } catch (...) {
        // Swallow — boundary handler cannot itself throw.
    }
}

}  // namespace dashpod::api
