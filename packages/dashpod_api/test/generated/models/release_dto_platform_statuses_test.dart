// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('ReleaseDtoPlatformStatuses', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = ReleaseDtoPlatformStatuses.values.first;
      final parsed = ReleaseDtoPlatformStatuses.maybeFromJson(
        instance.toJson(),
      )!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ReleaseDtoPlatformStatuses.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () =>
            ReleaseDtoPlatformStatuses.maybeFromJson('__invalid_enum_value__'),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in ReleaseDtoPlatformStatuses.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in ReleaseDtoPlatformStatuses.values) {
        expect(
          ReleaseDtoPlatformStatuses.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
