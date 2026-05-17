// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('CreatePatchEventRequestDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = CreatePatchEventRequestDto();
      final parsed = CreatePatchEventRequestDto.maybeFromJson(
        instance.toJson(),
      );
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CreatePatchEventRequestDto.maybeFromJson(null), isNull);
    });
  });
}
