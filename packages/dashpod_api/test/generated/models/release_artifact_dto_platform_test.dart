// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('ReleaseArtifactDtoPlatform', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = ReleaseArtifactDtoPlatform.values.first;
      final parsed = ReleaseArtifactDtoPlatform.maybeFromJson(
        instance.toJson(),
      );
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ReleaseArtifactDtoPlatform.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () =>
            ReleaseArtifactDtoPlatform.maybeFromJson('__invalid_enum_value__'),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in ReleaseArtifactDtoPlatform.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in ReleaseArtifactDtoPlatform.values) {
        expect(
          ReleaseArtifactDtoPlatform.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
