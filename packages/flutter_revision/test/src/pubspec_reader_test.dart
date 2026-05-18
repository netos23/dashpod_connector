import 'dart:io';

import 'package:flutter_revision/flutter_revision.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group(PubspecFlutterVersionReader, () {
    const reader = PubspecFlutterVersionReader();

    late Directory packageDir;
    late File pubspecFile;

    setUp(() {
      packageDir =
          Directory.systemTemp.createTempSync('flutter_revision_reader_test_');
      pubspecFile = File(p.join(packageDir.path, 'pubspec.yaml'));
    });

    tearDown(() => packageDir.deleteSync(recursive: true));

    group('when pubspec.yaml is missing', () {
      test('throws Exception', () {
        expect(
          () => reader.read(p.join(packageDir.path, 'nonexistent')),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('when pubspec.yaml has no flutter environment entry', () {
      setUp(() {
        pubspecFile.writeAsStringSync('name: my_app\n');
      });

      test('returns null', () {
        expect(reader.read(packageDir.path), isNull);
      });
    });

    group('when flutter entry is a pinned version', () {
      setUp(() {
        pubspecFile.writeAsStringSync('''
environment:
  sdk: ^3.8.1
  flutter: 3.22.0
''');
      });

      test('returns the Version', () {
        expect(reader.read(packageDir.path), equals(Version(3, 22, 0)));
      });
    });

    group('when flutter entry is a caret constraint', () {
      setUp(() {
        pubspecFile.writeAsStringSync('''
environment:
  sdk: ^3.8.1
  flutter: "^3.8.0"
''');
      });

      test('throws PubspecVersionConstraintException', () {
        expect(
          () => reader.read(packageDir.path),
          throwsA(isA<PubspecVersionConstraintException>()),
        );
      });

      test('exception carries the raw constraint string', () {
        try {
          reader.read(packageDir.path);
          fail('expected exception');
        } on PubspecVersionConstraintException catch (e) {
          expect(e.constraint, equals('^3.8.0'));
          expect(e.pubspecPath, contains('pubspec.yaml'));
        }
      });
    });

    group('when flutter entry is a range constraint', () {
      setUp(() {
        pubspecFile.writeAsStringSync('''
environment:
  sdk: ^3.8.1
  flutter: ">=3.8.0 <4.0.0"
''');
      });

      test('throws PubspecVersionConstraintException', () {
        expect(
          () => reader.read(packageDir.path),
          throwsA(isA<PubspecVersionConstraintException>()),
        );
      });
    });

    group('when pubspec.yaml is malformed', () {
      setUp(() {
        // Valid YAML but not a map — triggers the YamlMap check.
        pubspecFile.writeAsStringSync('- item1\n- item2\n');
      });

      test('throws Exception', () {
        expect(
          () => reader.read(packageDir.path),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
