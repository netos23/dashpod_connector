#pragma once

#include <cstdint>

namespace dashpod::time {

// Seconds since the Unix epoch. Matches the wire field
// PatchEvent.timestamp (seconds, not milliseconds).
std::uint64_t unix_timestamp();

}  // namespace dashpod::time
