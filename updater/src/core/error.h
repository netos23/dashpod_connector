#pragma once

#include <exception>
#include <string>
#include <utility>

namespace dashpod {

// Thrown internally; caught at every C-ABI boundary by log_on_error.
// Maps to the Rust reference's anyhow::Error usage.
class UpdaterError : public std::exception {
public:
    enum class Kind {
        InvalidArgument,
        AlreadyInitialized,
        ConfigNotInitialized,
        UpdateAlreadyInProgress,
        BadServerResponse,
        FailedToSaveState,
        InvalidState,
        Io,
        Network,
        BadPatch,
        InvalidSignature,
        Unknown,
    };

    UpdaterError(Kind kind, std::string message)
        : kind_(kind), message_(std::move(message)) {}

    [[nodiscard]] Kind kind() const noexcept { return kind_; }
    [[nodiscard]] const char* what() const noexcept override {
        return message_.c_str();
    }
    [[nodiscard]] const std::string& message() const noexcept {
        return message_;
    }

private:
    Kind kind_;
    std::string message_;
};

inline std::string to_string(UpdaterError::Kind kind) {
    using K = UpdaterError::Kind;
    switch (kind) {
        case K::InvalidArgument:         return "InvalidArgument";
        case K::AlreadyInitialized:      return "AlreadyInitialized";
        case K::ConfigNotInitialized:    return "ConfigNotInitialized";
        case K::UpdateAlreadyInProgress: return "UpdateAlreadyInProgress";
        case K::BadServerResponse:       return "BadServerResponse";
        case K::FailedToSaveState:       return "FailedToSaveState";
        case K::InvalidState:            return "InvalidState";
        case K::Io:                      return "Io";
        case K::Network:                 return "Network";
        case K::BadPatch:                return "BadPatch";
        case K::InvalidSignature:        return "InvalidSignature";
        case K::Unknown:                 return "Unknown";
    }
    return "Unknown";
}

}  // namespace dashpod
