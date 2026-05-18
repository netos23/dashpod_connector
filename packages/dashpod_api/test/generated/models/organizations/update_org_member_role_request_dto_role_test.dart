// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateOrgMemberRoleRequestDtoRole', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = UpdateOrgMemberRoleRequestDtoRole.values.first;
      final parsed = UpdateOrgMemberRoleRequestDtoRole.maybeFromJson(
        instance.toJson(),
      )!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(UpdateOrgMemberRoleRequestDtoRole.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => UpdateOrgMemberRoleRequestDtoRole.maybeFromJson(
          '__invalid_enum_value__',
        ),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in UpdateOrgMemberRoleRequestDtoRole.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in UpdateOrgMemberRoleRequestDtoRole.values) {
        expect(
          UpdateOrgMemberRoleRequestDtoRole.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
