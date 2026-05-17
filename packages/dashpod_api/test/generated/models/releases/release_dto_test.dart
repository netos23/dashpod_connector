// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('ReleaseDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = ReleaseDto();
      final parsed = ReleaseDto.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ReleaseDto.maybeFromJson(null), isNull);
    });
  });
}
