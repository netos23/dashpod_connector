import 'package:dashpod_updater/src/dashpod_updater_io.dart'
    if (dart.library.js_interop) 'package:dashpod_updater/src/dashpod_updater_web.dart';

/// The reason a call to [DashpodUpdater.update] failed.
enum UpdateFailureReason {
  /// No update is available.
  noUpdate,

  /// The update failed because the patch could not be downloaded.
  downloadFailed,

  /// The update failed because the patch failed to install.
  installFailed,

  /// The update failed for an unknown reason.
  unknown,
}

/// {@template read_patch_exception}
/// An exception thrown by [DashpodUpdater.readCurrentPatch] and
/// [DashpodUpdater.readNextPatch] when the read is unsuccessful.
/// {@endtemplate}
class ReadPatchException implements Exception {
  /// {@macro read_patch_exception}
  const ReadPatchException({required this.message});

  /// The human-readable error message.
  final String message;

  @override
  String toString() => '[DashpodUpdater] ReadPatchException: $message';
}

/// {@template update_exception}
/// An exception thrown by [DashpodUpdater.update] when the update is
/// unsuccessful.
/// {@endtemplate}
class UpdateException implements Exception {
  /// {@macro update_exception}
  const UpdateException({required this.message, required this.reason});

  /// The human-readable error message.
  final String message;

  /// The reason the update failed.
  final UpdateFailureReason reason;

  @override
  String toString() =>
      '[DashpodUpdater] UpdateException: $message (${reason.name})';
}

/// Logs a message explaining that the dashpod updater is unavailable.
///
/// This happens when the host process does not contain the dashpod engine
/// (e.g. plain `flutter build`/`flutter run`) or on platforms without
/// dashpod support (e.g. web).
void logDashpodEngineUnavailableMessage() {
  // Printing to the console is intentional here: we want it to be obvious
  // when the engine is unavailable so misconfigurations get noticed early.
  // ignore: avoid_print
  print('''
-------------------------------------------------------------------------------
The Dashpod Updater is unavailable in the current environment.
-------------------------------------------------------------------------------
This occurs when using pkg:dashpod_updater in an app that does not contain
the Dashpod Engine. Most commonly this is due to building with `flutter
build` or `flutter run` instead of the dashpod equivalent. It can also
occur when running on an unsupported platform (e.g. web).
''');
}

/// {@template patch}
/// An object representing a single patch (over-the-air update).
/// {@endtemplate}
class Patch {
  /// {@macro patch}
  const Patch({required this.number});

  /// The patch number. Strictly positive; patch numbers start at 1.
  final int number;
}

/// The current status of the app with respect to available updates.
enum UpdateStatus {
  /// The app is up to date (running the latest patch on its track).
  upToDate,

  /// A new update is available for download.
  outdated,

  /// The app is up to date, but a restart is required for the update to
  /// take effect.
  restartRequired,

  /// The update status is unavailable. This occurs when the updater is not
  /// available in the current build.
  ///
  /// See also:
  /// * [DashpodUpdater.isAvailable] to determine if the updater is available.
  unavailable,
}

/// {@template dashpod_updater}
/// Manage code-push updates for a Dashpod app.
/// {@endtemplate}
abstract class DashpodUpdater {
  /// {@macro dashpod_updater}
  factory DashpodUpdater() => DashpodUpdaterImpl();

  /// Whether the updater is available on the current platform.
  ///
  /// The most common reasons for this returning false are:
  /// 1. The app is running in debug mode (Dashpod only supports release
  ///    mode).
  /// 2. The app was not built with the dashpod engine.
  /// 3. The platform does not support dashpod (e.g. web).
  bool get isAvailable;

  /// Returns information about the currently installed patch.
  ///
  /// Returns `null` if no patch has been installed.
  /// Returns `null` if the updater is not available.
  /// Throws a [ReadPatchException] if the read is unsuccessful.
  Future<Patch?> readCurrentPatch();

  /// Returns information about the most recently downloaded patch.
  ///
  /// Returns the same patch as [readCurrentPatch] if no new patch has been
  /// downloaded.
  /// Returns `null` if the updater is not available.
  /// Throws a [ReadPatchException] if the read is unsuccessful.
  Future<Patch?> readNextPatch();

  /// Checks for an available patch on [track] (or [UpdateTrack.stable] if no
  /// track is specified) and returns the [UpdateStatus].
  ///
  /// This should be used to determine the update status before calling
  /// [update]. If this detects that the current patch has been rolled back,
  /// the current patch will be uninstalled. A separate call to [update] is
  /// required to install new patches.
  ///
  /// **Warning:** This method makes a network call that may take a long
  /// time to complete. Avoid awaiting it on the startup path; use
  /// `.then()` instead so the rest of the app can render.
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track});

  /// Updates the app to the latest patch available on [track], or
  /// [UpdateTrack.stable] if no track is specified.
  ///
  /// Completes when the patch is fully downloaded and ready to boot on
  /// next app launch. The app must be restarted for the update to take
  /// effect.
  ///
  /// Throws an [UpdateException] if the update fails. Does nothing if the
  /// updater is not available.
  Future<void> update({UpdateTrack? track});
}

/// A track to check for updates on.
///
/// In addition to the predefined tracks ([staging], [beta], [stable]) you
/// can create instances with custom names:
///
/// ```dart
/// final status =
///     await updater.checkForUpdate(track: UpdateTrack('my_custom_track'));
/// ```
extension type const UpdateTrack(String value) {
  /// Used for internal testing.
  static const staging = UpdateTrack('staging');

  /// Used for public testing.
  static const beta = UpdateTrack('beta');

  /// Used for general availability. This is the default track.
  static const stable = UpdateTrack('stable');

  /// The wire-protocol name of the track. Sent to the patch-check
  /// endpoint as the `channel` field.
  String get name => value;
}