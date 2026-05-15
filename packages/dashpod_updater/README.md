# dashpod_updater

Check for and download Dashpod over-the-air code-push updates from your app.

This package is the Dart side of Dashpod's code-push runtime. It is a port of
[`shorebird_code_push`][shorebird], adapted to talk to the in-repo C++
updater (`../../updater`) instead of Shorebird's upstream Rust library.

## How the pieces fit together

```
┌──────────────────────────────────────────────────────────────┐
│  Your Flutter app                                            │
│   ┌──────────────────────────────┐                           │
│   │  package:dashpod_updater     │  ← this package           │
│   │  - DashpodUpdater (public)   │                           │
│   │  - dart:ffi bindings         │                           │
│   └──────────────┬───────────────┘                           │
│                  │ C ABI (dashpod_*) — see                   │
│                  │ updater/include/dashpod/dart.h            │
│   ┌──────────────▼───────────────┐                           │
│   │  Dashpod C++ updater         │  ← ../../updater          │
│   │  (statically linked into     │                           │
│   │   the dashpod engine)        │                           │
│   └──────────────────────────────┘                           │
└──────────────────────────────────────────────────────────────┘
```

The Dart-stable C ABI surface that this package binds is defined by
`updater/include/dashpod/dart.h` and described in `private_docs/ARCHITECTURE.MD`
§12.2. ffigen configuration in `pubspec.yaml` points at that header so the
bindings in `lib/src/generated/` can be regenerated with `dart run ffigen`.

## Usage

```dart
import 'package:dashpod_updater/dashpod_updater.dart';

final updater = DashpodUpdater();

if (!updater.isAvailable) {
  // App was not built with the dashpod engine, or platform is unsupported.
  return;
}

updater.checkForUpdate().then((status) async {
  if (status == UpdateStatus.outdated) {
    try {
      await updater.update();
      // Restart the app to boot the new patch.
    } on UpdateException catch (e) {
      // Inspect e.reason for the failure category.
    }
  }
});
```

`checkForUpdate` and `update` both accept an optional `UpdateTrack`. The
predefined tracks are `UpdateTrack.stable` (default), `UpdateTrack.beta`,
and `UpdateTrack.staging`; you can also pass a custom track via
`UpdateTrack('my_custom_track')`.

## Status

The package compiles and statically analyses, but its behavioural test
suite (mirroring the shorebird reference) is gated on the in-repo C++
updater becoming linkable from a Dart test process. Until then, the
package is exercised end-to-end only when consumed by an app built with
the Dashpod engine.

[shorebird]: https://pub.dev/packages/shorebird_code_push
