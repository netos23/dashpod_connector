## 0.1.0

- Initial port of `shorebird_code_push` to the Dashpod C++ updater.
  - `DashpodUpdater` public API (`isAvailable`, `readCurrentPatch`,
    `readNextPatch`, `checkForUpdate`, `update`).
  - FFI bindings to `dashpod/dart.h` (hand-written, regenerable via
    `dart run ffigen`).
  - IO and web (stub) implementations selected by conditional import.
