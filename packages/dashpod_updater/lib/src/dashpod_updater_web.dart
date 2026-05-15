import 'package:dashpod_updater/src/dashpod_updater.dart';

/// {@template dashpod_updater_web}
/// Web stub for the Dashpod updater. Dashpod has no web implementation; this
/// class exists so apps that compile to JavaScript still link and so the
/// `isAvailable` check reports the correct value.
/// {@endtemplate}
class DashpodUpdaterImpl implements DashpodUpdater {
  /// {@macro dashpod_updater_web}
  DashpodUpdaterImpl() {
    logDashpodEngineUnavailableMessage();
  }

  @override
  bool get isAvailable => false;

  @override
  Future<Patch?> readCurrentPatch() async => null;

  @override
  Future<Patch?> readNextPatch() async => null;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async =>
      UpdateStatus.unavailable;

  @override
  Future<void> update({UpdateTrack? track}) async {}
}
