#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>

namespace dashpod {

// Whence values match libc's SEEK_SET / SEEK_CUR / SEEK_END so the C
// file-callback shim can pass them straight through without remapping.
enum class SeekWhence : int {
    Set = 0,
    Cur = 1,
    End = 2,
};

// Read-and-seek abstraction over a base snapshot. The Rust reference
// names this trait `ReadSeek`. Two production implementations exist:
//   - a std::ifstream wrapper (desktop / unit tests)
//   - a CFile wrapper over DashpodFileCallbacks (iOS)
// Android uses a memory-mapped Cursor<Mmap>, modelled as an in-memory
// span impl.
class IReadSeek {
public:
    virtual ~IReadSeek() = default;

    // Reads up to `count` bytes into `buffer`. Returns the number of
    // bytes actually read (0 ⇒ EOF).
    virtual std::size_t read(std::uint8_t* buffer, std::size_t count) = 0;

    // Repositions the cursor. Returns the new absolute offset from the
    // start of the file, or a negative value on error.
    virtual std::int64_t seek(std::int64_t offset, SeekWhence whence) = 0;
};

using ReadSeekPtr = std::unique_ptr<IReadSeek>;

// Factory used by config.cpp to open the base snapshot. Modelled after
// the Rust `ExternalFileProvider` trait.
class IExternalFileProvider {
public:
    virtual ~IExternalFileProvider() = default;
    virtual ReadSeekPtr open() = 0;
};

using ExternalFileProviderPtr = std::unique_ptr<IExternalFileProvider>;

}  // namespace dashpod
