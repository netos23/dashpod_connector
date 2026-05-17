// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('CreatePatchArtifactResponseDtoPlatform', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = CreatePatchArtifactResponseDtoPlatform.values.first;
      final parsed = CreatePatchArtifactResponseDtoPlatform.maybeFromJson(
        instance.toJson(),
      )!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(
        CreatePatchArtifactResponseDtoPlatform.maybeFromJson(null),
        isNull,
      );
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => CreatePatchArtifactResponseDtoPlatform.maybeFromJson(
          '__invalid_enum_value__',
        ),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in CreatePatchArtifactResponseDtoPlatform.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in CreatePatchArtifactResponseDtoPlatform.values) {
        expect(
          CreatePatchArtifactResponseDtoPlatform.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
