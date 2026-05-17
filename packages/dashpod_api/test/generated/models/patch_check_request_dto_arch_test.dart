// GENERATED — do not hand-edit.
import 'package:dashpod_api/dashpod_api.dart';
import 'package:test/test.dart';

void main() {
  group('PatchCheckRequestDtoArch', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PatchCheckRequestDtoArch.values.first;
      final parsed = PatchCheckRequestDtoArch.maybeFromJson(instance.toJson());
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PatchCheckRequestDtoArch.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PatchCheckRequestDtoArch.maybeFromJson('__invalid_enum_value__'),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in PatchCheckRequestDtoArch.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in PatchCheckRequestDtoArch.values) {
        expect(
          PatchCheckRequestDtoArch.fromJson(value.toJson()),
          equals(value),
        );
      }
    });
  });
}
