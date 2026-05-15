import 'dart:ffi' as ffi;
import 'dart:ffi';

import 'package:dashpod_updater/src/dashpod_updater.dart';
import 'package:dashpod_updater/src/generated/updater_bindings.g.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

/// {@template updater}
/// A wrapper around the generated [UpdaterBindings] that translates ffi
/// types into easier-to-use Dart types and handles channel-string
/// allocation.
/// {@endtemplate}
class Updater {
  /// {@macro updater}
  const Updater();

  /// The ffi bindings to the dashpod updater library.
  ///
  /// The library symbols are looked up in the host process by default — the
  /// dashpod engine statically links the updater so the symbols are visible
  /// without an explicit `DynamicLibrary.open`.
  @visibleForTesting
  static UpdaterBindings bindings =
      UpdaterBindings(ffi.DynamicLibrary.process());

  /// The currently active patch number, or 0 if running the base release.
  int currentPatchNumber() => bindings.dashpod_current_boot_patch_number();

  /// The next patch number that will be loaded on the next launch. Will be
  /// the same as [currentPatchNumber] if no new patch is available.
  int nextPatchNumber() => bindings.dashpod_next_boot_patch_number();

  /// Whether a new patch is available for download on [track].
  ///
  /// A null [track] tells the C ABI to fall back to the channel configured
  /// in the bundled `dashpod.yaml`, which itself defaults to `"stable"`.
  bool checkForDownloadableUpdate({UpdateTrack? track}) {
    final channel = _allocateTrack(track);
    try {
      return bindings.dashpod_check_for_downloadable_update(channel);
    } finally {
      _freeTrack(channel);
    }
  }

  /// Downloads the latest patch on [track], if available, and returns a
  /// pointer to a heap-allocated [DashpodUpdateResult] describing what
  /// happened. The caller must release the pointer with [freeUpdateResult].
  Pointer<DashpodUpdateResult> update({UpdateTrack? track}) {
    final channel = _allocateTrack(track);
    try {
      return bindings.dashpod_update_with_result(channel);
    } finally {
      _freeTrack(channel);
    }
  }

  /// Frees an update result allocated by the updater.
  void freeUpdateResult(Pointer<DashpodUpdateResult> ptr) =>
      bindings.dashpod_free_update_result(ptr);
}

Pointer<Char> _allocateTrack(UpdateTrack? track) {
  if (track == null) return ffi.nullptr;
  return track.name.toNativeUtf8().cast<Char>();
}

void _freeTrack(Pointer<Char> ptr) {
  if (ptr == ffi.nullptr) return;
  calloc.free(ptr.cast<Utf8>());
}