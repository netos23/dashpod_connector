// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('PatchArtifactDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PatchArtifactDto();
      final parsed = PatchArtifactDto.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PatchArtifactDto.maybeFromJson(null), isNull);
    });
  });
}
