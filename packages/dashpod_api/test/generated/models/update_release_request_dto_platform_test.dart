// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateReleaseRequestDtoPlatform', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = UpdateReleaseRequestDtoPlatform.values.first;
      final parsed = UpdateReleaseRequestDtoPlatform.maybeFromJson(
        instance.toJson(),
      )!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(UpdateReleaseRequestDtoPlatform.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => UpdateReleaseRequestDtoPlatform.maybeFromJson(
          '__invalid_enum_value__',
        ),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in UpdateReleaseRequestDtoPlatform.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in UpdateReleaseRequestDtoPlatform.values) {
        expect(
          UpdateReleaseRequestDtoPlatform.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
