// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('PatchCheckResponseDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PatchCheckResponseDto();
      final parsed = PatchCheckResponseDto.maybeFromJson(instance.toJson());
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PatchCheckResponseDto.maybeFromJson(null), isNull);
    });
  });
}
