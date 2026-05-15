import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:dashpod_updater/src/dashpod_updater.dart';
import 'package:dashpod_updater/src/generated/updater_bindings.g.dart';
import 'package:dashpod_updater/src/updater.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

/// Type definition for [Isolate.run]. Exposed so tests can substitute a
/// synchronous runner that exercises the code path without spawning a
/// real isolate.
@visibleForTesting
typedef IsolateRun = Future<R> Function<R>(
  FutureOr<R> Function(), {
  String? debugName,
});

/// {@template dashpod_updater_io}
/// The native (FFI-backed) Dashpod updater. Used on every Dart platform
/// except web — the conditional import in `dashpod_updater.dart` swaps in
/// the web stub there.
/// {@endtemplate}
class DashpodUpdaterImpl implements DashpodUpdater {
  /// {@macro dashpod_updater_io}
  DashpodUpdaterImpl({Updater? updater, IsolateRun? run})
      : _updater = updater ?? const Updater(),
        _run = run ?? Isolate.run {
    try {
      // Probe the native library: if the dashpod engine is not statically
      // linked into the host process the symbol lookup throws.
      //
      // FIXME: Run this in an isolate or refactor the updater to avoid
      // risking a hang — if another thread is also calling into the
      // updater at the same time the underlying C++ code could block
      // acquiring the config lock.
      _updater.currentPatchNumber();
      _isAvailable = true;
      // We intentionally catch every error so a missing engine surfaces as
      // `isAvailable == false` rather than propagating up the call stack.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      logDashpodEngineUnavailableMessage();
      _isAvailable = false;
    }
  }

  late final bool _isAvailable;

  final Updater _updater;

  final IsolateRun _run;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<Patch?> readCurrentPatch() => _readPatch(_updater.currentPatchNumber);

  @override
  Future<Patch?> readNextPatch() => _readPatch(_updater.nextPatchNumber);

  Future<Patch?> _readPatch(int Function() fn) async {
    if (!_isAvailable) return null;
    return _run(() {
      try {
        final patchNumber = fn();
        return patchNumber > 0 ? Patch(number: patchNumber) : null;
      } catch (error) {
        throw ReadPatchException(message: '$error');
      }
    });
  }

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async {
    if (!_isAvailable) return UpdateStatus.unavailable;

    // First, ask the server whether a new patch is available for download.
    final isUpdateAvailable = await _run(
      () => _updater.checkForDownloadableUpdate(track: track),
    );
    if (isUpdateAvailable) return UpdateStatus.outdated;

    // Otherwise check whether a previously-downloaded patch is waiting for
    // a restart. A restart is required when the current and next patches
    // differ — which covers both "new patch downloaded" (next != current)
    // and "current patch rolled back" (current != null && next == null).
    final (current, next) = await (readCurrentPatch(), readNextPatch()).wait;
    return current?.number != next?.number
        ? UpdateStatus.restartRequired
        : UpdateStatus.upToDate;
  }

  @override
  Future<void> update({UpdateTrack? track}) async {
    if (!_isAvailable) return;

    final result = await _run(() => _updater.update(track: track));

    const unknownErrorMessage = 'An unknown error occurred.';

    try {
      if (result == nullptr) {
        throw const UpdateException(
          reason: UpdateFailureReason.unknown,
          message: unknownErrorMessage,
        );
      }

      final status = result.ref.status;

      // Benign outcomes of `update()`:
      //   - DASHPOD_UPDATE_INSTALLED:  a new patch was installed.
      //   - DASHPOD_NO_UPDATE:         already running the latest patch.
      //   - DASHPOD_UPDATE_IN_PROGRESS: the background updater thread was
      //     already running; the caller's invocation was a no-op. This is
      //     expected and must not surface as an exception.
      if (status == DASHPOD_UPDATE_INSTALLED ||
          status == DASHPOD_NO_UPDATE ||
          status == DASHPOD_UPDATE_IN_PROGRESS) {
        return;
      }

      final reason = status.toFailureReason();
      final message = result.ref.message != nullptr
          ? result.ref.message.cast<Utf8>().toDartString()
          : unknownErrorMessage;
      throw UpdateException(message: message, reason: reason);
    } finally {
      _updater.freeUpdateResult(result);
    }
  }
}

extension on int {
  UpdateFailureReason toFailureReason() {
    switch (this) {
      case DASHPOD_NO_UPDATE:
        return UpdateFailureReason.noUpdate;
      case DASHPOD_UPDATE_HAD_ERROR:
        return UpdateFailureReason.downloadFailed;
      case DASHPOD_UPDATE_IS_BAD_PATCH:
        return UpdateFailureReason.installFailed;
      case DASHPOD_UPDATE_ERROR:
        return UpdateFailureReason.unknown;
      default:
        return UpdateFailureReason.unknown;
    }
  }
}