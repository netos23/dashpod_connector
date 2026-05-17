// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('CreateReleaseArtifactRequestDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = CreateReleaseArtifactRequestDto();
      final parsed = CreateReleaseArtifactRequestDto.maybeFromJson(
        instance.toJson(),
      );
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CreateReleaseArtifactRequestDto.maybeFromJson(null), isNull);
    });
  });
}
