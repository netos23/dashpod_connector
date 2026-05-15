// ignore_for_file: unused_element, unused_field, camel_case_types, constant_identifier_names, non_constant_identifier_names
//
// Hand-written mirror of `updater/include/dashpod/dart.h`. The layout matches
// what ffigen would produce so that running ffigen (configured in
// pubspec.yaml) overwrites this file cleanly. Do not edit by hand if the
// header changes — regenerate with `dart run ffigen`.

import 'dart:ffi' as ffi;

/// Status code returned by [DashpodUpdateResult.status] when the update
/// failed for an unspecified reason.
const int DASHPOD_UPDATE_ERROR = -1;

/// Status code returned by [DashpodUpdateResult.status] when no update was
/// available on the requested channel.
const int DASHPOD_NO_UPDATE = 0;

/// Status code returned by [DashpodUpdateResult.status] when a new patch
/// was downloaded and installed successfully.
const int DASHPOD_UPDATE_INSTALLED = 1;

/// Status code returned by [DashpodUpdateResult.status] when an update was
/// attempted but failed mid-way (e.g. network error during download).
const int DASHPOD_UPDATE_HAD_ERROR = 2;

/// Status code returned by [DashpodUpdateResult.status] when the downloaded
/// patch failed validation (hash mismatch, bad signature, …) and was
/// tombstoned.
const int DASHPOD_UPDATE_IS_BAD_PATCH = 3;

/// Status code returned by [DashpodUpdateResult.status] when another updater
/// call (typically the background updater thread) is already running. The
/// caller did not start a new update; this is benign.
const int DASHPOD_UPDATE_IN_PROGRESS = 4;

/// The structure returned by `dashpod_update_with_result`. Must be freed by
/// the caller via `dashpod_free_update_result`.
final class DashpodUpdateResult extends ffi.Struct {
  @ffi.Int32()
  external int status;

  external ffi.Pointer<ffi.Char> message;
}

/// Bindings to the Dart-stable surface of the dashpod updater C ABI
/// (`updater/include/dashpod/dart.h`).
class UpdaterBindings {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  UpdaterBindings(ffi.DynamicLibrary dynamicLibrary)
      : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  UpdaterBindings.fromLookup(
    ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
        lookup,
  ) : _lookup = lookup;

  /// The patch number this process is currently running, or 0 if running the
  /// base release.
  int dashpod_current_boot_patch_number() {
    return _dashpod_current_boot_patch_number();
  }

  late final _dashpod_current_boot_patch_numberPtr =
      _lookup<ffi.NativeFunction<ffi.UintPtr Function()>>(
    'dashpod_current_boot_patch_number',
  );
  late final _dashpod_current_boot_patch_number =
      _dashpod_current_boot_patch_numberPtr.asFunction<int Function()>();

  /// The patch number that will boot on the next launch, or 0 if the next
  /// boot is the base release.
  int dashpod_next_boot_patch_number() {
    return _dashpod_next_boot_patch_number();
  }

  late final _dashpod_next_boot_patch_numberPtr =
      _lookup<ffi.NativeFunction<ffi.UintPtr Function()>>(
    'dashpod_next_boot_patch_number',
  );
  late final _dashpod_next_boot_patch_number =
      _dashpod_next_boot_patch_numberPtr.asFunction<int Function()>();

  /// Synchronously check whether an update is available for download on the
  /// given channel. Pass `nullptr` to fall back to the bundled
  /// `dashpod.yaml`'s channel (which itself defaults to `"stable"`).
  bool dashpod_check_for_downloadable_update(ffi.Pointer<ffi.Char> channel) {
    return _dashpod_check_for_downloadable_update(channel);
  }

  late final _dashpod_check_for_downloadable_updatePtr = _lookup<
      ffi.NativeFunction<
          ffi.Bool Function(ffi.Pointer<ffi.Char>)>>(
    'dashpod_check_for_downloadable_update',
  );
  late final _dashpod_check_for_downloadable_update =
      _dashpod_check_for_downloadable_updatePtr.asFunction<
          bool Function(ffi.Pointer<ffi.Char>)>();

  /// Synchronously download + install an update on the given channel. The
  /// caller owns the returned pointer and must release it with
  /// `dashpod_free_update_result`.
  ffi.Pointer<DashpodUpdateResult> dashpod_update_with_result(
    ffi.Pointer<ffi.Char> channel,
  ) {
    return _dashpod_update_with_result(channel);
  }

  late final _dashpod_update_with_resultPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<DashpodUpdateResult> Function(
              ffi.Pointer<ffi.Char>)>>('dashpod_update_with_result');
  late final _dashpod_update_with_result =
      _dashpod_update_with_resultPtr.asFunction<
          ffi.Pointer<DashpodUpdateResult> Function(ffi.Pointer<ffi.Char>)>();

  /// Frees a result previously returned by `dashpod_update_with_result`.
  /// Safe to call with a null pointer.
  void dashpod_free_update_result(ffi.Pointer<DashpodUpdateResult> result) {
    _dashpod_free_update_result(result);
  }

  late final _dashpod_free_update_resultPtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
              ffi.Pointer<DashpodUpdateResult>)>>('dashpod_free_update_result');
  late final _dashpod_free_update_result = _dashpod_free_update_resultPtr
      .asFunction<void Function(ffi.Pointer<DashpodUpdateResult>)>();
}