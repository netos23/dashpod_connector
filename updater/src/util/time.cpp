#include "util/time.h"

#include <chrono>

namespace dashpod::time {

std::uint64_t unix_timestamp() {
    const auto now = std::chrono::system_clock::now().time_since_epoch();
    return static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::seconds>(now).count());
}

}  // namespace dashpod::time
