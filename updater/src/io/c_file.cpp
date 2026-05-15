#include "io/c_file.h"

#include "core/error.h"
#include "util/logging.h"

namespace dashpod::io {

namespace {

class CFile final : public IReadSeek {
public:
    CFile(DashpodFileCallbacks callbacks, void* handle)
        : callbacks_(callbacks), handle_(handle) {}

    ~CFile() override {
        if (callbacks_.close != nullptr && handle_ != nullptr) {
            callbacks_.close(handle_);
        }
    }

    CFile(const CFile&) = delete;
    CFile& operator=(const CFile&) = delete;

    std::size_t read(std::uint8_t* buffer, std::size_t count) override {
        if (callbacks_.read == nullptr) return 0;
        return callbacks_.read(handle_, buffer, count);
    }

    std::int64_t seek(std::int64_t offset, SeekWhence whence) override {
        if (callbacks_.seek == nullptr) return -1;
        return callbacks_.seek(handle_, offset, static_cast<std::int32_t>(whence));
    }

private:
    DashpodFileCallbacks callbacks_;
    void*                handle_;
};

}  // namespace

ReadSeekPtr CFileProvider::open() {
    if (callbacks_.open == nullptr) {
        throw UpdaterError(UpdaterError::Kind::InvalidArgument,
            "CFileProvider: open callback is null");
    }
    void* h = callbacks_.open();
    if (h == nullptr) {
        throw UpdaterError(UpdaterError::Kind::Io, "CFile open failed");
    }
    return std::make_unique<CFile>(callbacks_, h);
}

}  // namespace dashpod::io
