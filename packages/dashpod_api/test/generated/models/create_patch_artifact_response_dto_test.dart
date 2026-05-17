// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('CreatePatchArtifactResponseDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = CreatePatchArtifactResponseDto();
      final parsed = CreatePatchArtifactResponseDto.maybeFromJson(
        instance.toJson(),
      );
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CreatePatchArtifactResponseDto.maybeFromJson(null), isNull);
    });
  });
}
