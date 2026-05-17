// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('AppDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = AppDto();
      final parsed = AppDto.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(AppDto.maybeFromJson(null), isNull);
    });
  });
}
