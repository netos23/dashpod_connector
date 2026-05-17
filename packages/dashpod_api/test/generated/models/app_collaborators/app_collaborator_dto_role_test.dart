// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('AppCollaboratorDtoRole', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = AppCollaboratorDtoRole.values.first;
      final parsed = AppCollaboratorDtoRole.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(AppCollaboratorDtoRole.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => AppCollaboratorDtoRole.maybeFromJson('__invalid_enum_value__'),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in AppCollaboratorDtoRole.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in AppCollaboratorDtoRole.values) {
        expect(AppCollaboratorDtoRole.fromJson(value.toJson()), equals(value));
      }
    });
  });
}
