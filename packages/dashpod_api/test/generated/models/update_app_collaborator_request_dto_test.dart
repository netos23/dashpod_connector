// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateAppCollaboratorRequestDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = UpdateAppCollaboratorRequestDto();
      final parsed = UpdateAppCollaboratorRequestDto.maybeFromJson(
        instance.toJson(),
      )!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(UpdateAppCollaboratorRequestDto.maybeFromJson(null), isNull);
    });
  });
}
