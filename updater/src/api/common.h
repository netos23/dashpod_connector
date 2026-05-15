#pragma once

#include <optional>
#include <string>
#include <utility>

namespace dashpod::api {

// Allocate a C string copy of `s`. Caller-owned; free with free_c_string.
// Returns nullptr on allocation failure.
char* allocate_c_string(const std::string& s) noexcept;

// Frees a string returned by allocate_c_string. No-op on null.
void  free_c_string(const char* s) noexcept;

// Convert a possibly-null C string to a std::string. Throws
// UpdaterError on null.
std::string to_rust(const char* s);

// Same as to_rust but null-safe: returns nullopt on null.
std::optional<std::string> to_rust_option(const char* s);

// Logs an exception caught at the FFI boundary. Linked from
// log_on_error; visible to that template so it can be invoked
// without dragging the full logging header into every translation
// unit that includes this one.
void log_error_at_boundary(const char* ctx, const char* what) noexcept;

// Run `f`. On any exception, log and return `fallback`. The boundary
// pattern from updater.rs's `log_on_error` — every extern "C" entry
// point funnels through this so the library cannot unwind into the
// embedder.
template <typename Fn, typename Fallback>
auto log_on_error(Fn&& fn, const char* context, Fallback fallback) {
    try {
        return std::forward<Fn>(fn)();
    } catch (const std::exception& e) {
        log_error_at_boundary(context, e.what());
        return fallback;
    } catch (...) {
        log_error_at_boundary(context, "<unknown>");
        return fallback;
    }
}

}  // namespace dashpod::api
