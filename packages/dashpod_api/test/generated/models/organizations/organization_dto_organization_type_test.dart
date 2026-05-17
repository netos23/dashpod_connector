// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('OrganizationDtoOrganizationType', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = OrganizationDtoOrganizationType.values.first;
      final parsed = OrganizationDtoOrganizationType.maybeFromJson(
        instance.toJson(),
      )!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(OrganizationDtoOrganizationType.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => OrganizationDtoOrganizationType.maybeFromJson(
          '__invalid_enum_value__',
        ),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in OrganizationDtoOrganizationType.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in OrganizationDtoOrganizationType.values) {
        expect(
          OrganizationDtoOrganizationType.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
