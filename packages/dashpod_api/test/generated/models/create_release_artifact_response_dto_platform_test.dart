// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('CreateReleaseArtifactResponseDtoPlatform', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = CreateReleaseArtifactResponseDtoPlatform.values.first;
      final parsed = CreateReleaseArtifactResponseDtoPlatform.maybeFromJson(
        instance.toJson(),
      );
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(
        CreateReleaseArtifactResponseDtoPlatform.maybeFromJson(null),
        isNull,
      );
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => CreateReleaseArtifactResponseDtoPlatform.maybeFromJson(
          '__invalid_enum_value__',
        ),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in CreateReleaseArtifactResponseDtoPlatform.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in CreateReleaseArtifactResponseDtoPlatform.values) {
        expect(
          CreateReleaseArtifactResponseDtoPlatform.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
