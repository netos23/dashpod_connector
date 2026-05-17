// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('PatchArtifactDtoPlatform', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PatchArtifactDtoPlatform.values.first;
      final parsed = PatchArtifactDtoPlatform.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PatchArtifactDtoPlatform.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PatchArtifactDtoPlatform.maybeFromJson('__invalid_enum_value__'),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in PatchArtifactDtoPlatform.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in PatchArtifactDtoPlatform.values) {
        expect(
          PatchArtifactDtoPlatform.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
