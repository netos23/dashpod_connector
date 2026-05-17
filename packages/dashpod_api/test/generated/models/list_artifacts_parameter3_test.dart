// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('ListArtifactsParameter3', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = ListArtifactsParameter3.values.first;
      final parsed = ListArtifactsParameter3.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ListArtifactsParameter3.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => ListArtifactsParameter3.maybeFromJson('__invalid_enum_value__'),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in ListArtifactsParameter3.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in ListArtifactsParameter3.values) {
        expect(ListArtifactsParameter3.fromJson(value.toJson()), equals(value));
      }
    });
  });
}
