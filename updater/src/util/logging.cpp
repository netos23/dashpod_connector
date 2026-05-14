#include "util/logging.h"

#include <iostream>
#include <mutex>

#if defined(__ANDROID__)
  #include <android/log.h>
#elif defined(__APPLE__)
  #include <os/log.h>
#endif

namespace dashpod::log {

namespace {

const char* level_tag(Level level) {
    switch (level) {
        case Level::Debug: return "DEBUG";
        case Level::Info:  return "INFO";
        case Level::Warn:  return "WARN";
        case Level::Error: return "ERROR";
    }
    return "INFO";
}

std::mutex& cerr_mutex() {
    static std::mutex m;
    return m;
}

}  // namespace

void log(Level level, std::string_view message) {
#if defined(__ANDROID__)
    int prio = ANDROID_LOG_INFO;
    switch (level) {
        case Level::Debug: prio = ANDROID_LOG_DEBUG; break;
        case Level::Info:  prio = ANDROID_LOG_INFO;  break;
        case Level::Warn:  prio = ANDROID_LOG_WARN;  break;
        case Level::Error: prio = ANDROID_LOG_ERROR; break;
    }
    __android_log_print(prio, "dashpod_updater", "%.*s",
                        static_cast<int>(message.size()), message.data());
#elif defined(__APPLE__)
    os_log_type_t type = OS_LOG_TYPE_INFO;
    switch (level) {
        case Level::Debug: type = OS_LOG_TYPE_DEBUG;   break;
        case Level::Info:  type = OS_LOG_TYPE_INFO;    break;
        case Level::Warn:  type = OS_LOG_TYPE_DEFAULT; break;
        case Level::Error: type = OS_LOG_TYPE_ERROR;   break;
    }
    os_log_with_type(OS_LOG_DEFAULT, type, "[dashpod_updater] %.*s",
                     static_cast<int>(message.size()), message.data());
#else
    std::lock_guard<std::mutex> lock(cerr_mutex());
    std::cerr << "[dashpod_updater] [" << level_tag(level) << "] "
              << message << "\n";
#endif
}

}  // namespace dashpod::log
