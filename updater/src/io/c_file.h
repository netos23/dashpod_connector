#pragma once

#include "dashpod/engine.h"
#include "io/read_seek.h"

namespace dashpod::io {

// Wraps a DashpodFileCallbacks table in the IExternalFileProvider /
// IReadSeek interfaces used by the rest of the codebase.
class CFileProvider final : public IExternalFileProvider {
public:
    explicit CFileProvider(DashpodFileCallbacks cb) : callbacks_(cb) {}
    ReadSeekPtr open() override;

private:
    DashpodFileCallbacks callbacks_;
};

}  // namespace dashpod::io
