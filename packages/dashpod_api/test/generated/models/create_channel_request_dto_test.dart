// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('CreateChannelRequestDto', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = CreateChannelRequestDto();
      final parsed = CreateChannelRequestDto.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CreateChannelRequestDto.maybeFromJson(null), isNull);
    });
  });
}
