import 'dart:io';

import 'package:flutter_revision/flutter_revision.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group(FvmConfigReader, () {
    const reader = FvmConfigReader();

    late Directory packageDir;

    setUp(() {
      packageDir =
          Directory.systemTemp.createTempSync('flutter_revision_fvm_test_');
    });

    tearDown(() => packageDir.deleteSync(recursive: true));

    group('when no FVM config files are present', () {
      test('returns null', () {
        expect(reader.read(packageDir.path), isNull);
      });
    });

    group('.fvmrc (FVM v3)', () {
      late File fvmrc;

      setUp(() {
        fvmrc = File(p.join(packageDir.path, '.fvmrc'));
      });

      group('when flutter key has a pinned version', () {
        setUp(() {
          fvmrc.writeAsStringSync('{"flutter": "3.24.0"}');
        });

        test('returns the parsed Version', () {
          expect(reader.read(packageDir.path), equals(Version(3, 24, 0)));
        });
      });

      group('when flutter key is a channel name', () {
        setUp(() {
          fvmrc.writeAsStringSync('{"flutter": "stable"}');
        });

        test('returns null', () {
          expect(reader.read(packageDir.path), isNull);
        });
      });

      group('when flutter key is absent', () {
        setUp(() {
          fvmrc.writeAsStringSync('{"flavors": {}}');
        });

        test('returns null', () {
          expect(reader.read(packageDir.path), isNull);
        });
      });

      group('when the file is malformed JSON', () {
        setUp(() {
          fvmrc.writeAsStringSync('not json');
        });

        test('throws FormatException', () {
          expect(
            () => reader.read(packageDir.path),
            throwsA(isA<FormatException>()),
          );
        });
      });
    });

    group('.fvm/fvm_config.json (FVM v2)', () {
      late File fvmConfig;

      setUp(() {
        final fvmDir = Directory(p.join(packageDir.path, '.fvm'))
          ..createSync();
        fvmConfig = File(p.join(fvmDir.path, 'fvm_config.json'));
      });

      group('when flutterSdkVersion has a pinned version', () {
        setUp(() {
          fvmConfig.writeAsStringSync('{"flutterSdkVersion": "3.22.0"}');
        });

        test('returns the parsed Version', () {
          expect(reader.read(packageDir.path), equals(Version(3, 22, 0)));
        });
      });

      group('when flutterSdkVersion is a channel name', () {
        setUp(() {
          fvmConfig.writeAsStringSync('{"flutterSdkVersion": "beta"}');
        });

        test('returns null', () {
          expect(reader.read(packageDir.path), isNull);
        });
      });

      group('when flutterSdkVersion key is absent', () {
        setUp(() {
          fvmConfig.writeAsStringSync('{}');
        });

        test('returns null', () {
          expect(reader.read(packageDir.path), isNull);
        });
      });

      group('when the file is malformed JSON', () {
        setUp(() {
          fvmConfig.writeAsStringSync('not json');
        });

        test('throws FormatException', () {
          expect(
            () => reader.read(packageDir.path),
            throwsA(isA<FormatException>()),
          );
        });
      });
    });

    group('precedence: .fvmrc takes priority over .fvm/fvm_config.json', () {
      setUp(() {
        File(p.join(packageDir.path, '.fvmrc'))
            .writeAsStringSync('{"flutter": "3.24.0"}');
        final fvmDir = Directory(p.join(packageDir.path, '.fvm'))..createSync();
        File(p.join(fvmDir.path, 'fvm_config.json'))
            .writeAsStringSync('{"flutterSdkVersion": "3.19.0"}');
      });

      test('returns the .fvmrc version', () {
        expect(reader.read(packageDir.path), equals(Version(3, 24, 0)));
      });
    });

    group('falls back to .fvm/fvm_config.json when .fvmrc has no version', () {
      setUp(() {
        File(p.join(packageDir.path, '.fvmrc'))
            .writeAsStringSync('{"flutter": "stable"}');
        final fvmDir = Directory(p.join(packageDir.path, '.fvm'))..createSync();
        File(p.join(fvmDir.path, 'fvm_config.json'))
            .writeAsStringSync('{"flutterSdkVersion": "3.19.0"}');
      });

      test('returns the .fvm/fvm_config.json version', () {
        expect(reader.read(packageDir.path), equals(Version(3, 19, 0)));
      });
    });
  });
}