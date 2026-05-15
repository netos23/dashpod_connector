import 'package:dashpod_updater/dashpod_updater.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateTrack', () {
    test('predefined tracks have the expected wire names', () {
      expect(UpdateTrack.stable.name, 'stable');
      expect(UpdateTrack.beta.name, 'beta');
      expect(UpdateTrack.staging.name, 'staging');
    });

    test('custom track preserves its name', () {
      expect(const UpdateTrack('my_custom_track').name, 'my_custom_track');
    });
  });

  group('Patch', () {
    test('exposes its patch number', () {
      expect(const Patch(number: 7).number, 7);
    });
  });

  group('UpdateException', () {
    test('toString includes the reason name', () {
      const exception = UpdateException(
        message: 'boom',
        reason: UpdateFailureReason.downloadFailed,
      );
      expect(exception.toString(), contains('downloadFailed'));
      expect(exception.toString(), contains('boom'));
    });
  });

  group('ReadPatchException', () {
    test('toString includes the message', () {
      const exception = ReadPatchException(message: 'no patch');
      expect(exception.toString(), contains('no patch'));
    });
  });

  // Note: behavioural tests for `DashpodUpdater` itself live in the
  // shorebird reference suite and depend on the native library being
  // loaded. They will be ported once the C++ updater can be linked here.
}
