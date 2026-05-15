#pragma once

#include <sstream>
#include <string>
#include <string_view>

namespace dashpod::log {

enum class Level { Debug, Info, Warn, Error };

void log(Level level, std::string_view message);

inline void log_string(Level level, const std::string& message) {
    log(level, message);
}

template <typename... Args>
std::string format_concat(Args&&... args) {
    std::ostringstream oss;
    (oss << ... << std::forward<Args>(args));
    return oss.str();
}

}  // namespace dashpod::log

#define DASHPOD_LOG(level, ...) \
    ::dashpod::log::log_string( \
        ::dashpod::log::Level::level, \
        ::dashpod::log::format_concat(__VA_ARGS__))

#define DASHPOD_DEBUG(...) DASHPOD_LOG(Debug, __VA_ARGS__)
#define DASHPOD_INFO(...)  DASHPOD_LOG(Info,  __VA_ARGS__)
#define DASHPOD_WARN(...)  DASHPOD_LOG(Warn,  __VA_ARGS__)
#define DASHPOD_ERROR(...) DASHPOD_LOG(Error, __VA_ARGS__)
