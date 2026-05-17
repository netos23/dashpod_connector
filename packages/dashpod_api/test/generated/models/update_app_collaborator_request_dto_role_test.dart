// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateAppCollaboratorRequestDtoRole', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = UpdateAppCollaboratorRequestDtoRole.values.first;
      final parsed = UpdateAppCollaboratorRequestDtoRole.maybeFromJson(
        instance.toJson(),
      )!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(UpdateAppCollaboratorRequestDtoRole.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => UpdateAppCollaboratorRequestDtoRole.maybeFromJson(
          '__invalid_enum_value__',
        ),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in UpdateAppCollaboratorRequestDtoRole.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in UpdateAppCollaboratorRequestDtoRole.values) {
        expect(
          UpdateAppCollaboratorRequestDtoRole.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
