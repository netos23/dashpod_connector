// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('CreateAppCollaboratorRequestDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = CreateAppCollaboratorRequestDto();
      final parsed = CreateAppCollaboratorRequestDto.maybeFromJson(
        instance.toJson(),
      )!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CreateAppCollaboratorRequestDto.maybeFromJson(null), isNull);
    });
  });
}
