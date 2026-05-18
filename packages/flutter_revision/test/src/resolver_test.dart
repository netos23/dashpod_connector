import 'dart:io';

import 'package:flutter_revision/flutter_revision.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group(FlutterRevisionResolver, () {
    late Directory packageDir;
    late File pubspecFile;
    late List<String> logMessages;
    late FlutterRevisionResolver resolver;

    setUp(() {
      packageDir =
          Directory.systemTemp.createTempSync('flutter_revision_resolver_test_');
      pubspecFile = File(p.join(packageDir.path, 'pubspec.yaml'));
      logMessages = <String>[];
      resolver = FlutterRevisionResolver(log: logMessages.add);
    });

    tearDown(() => packageDir.deleteSync(recursive: true));

    group('FVM config resolution', () {
      setUp(() {
        // pubspec.yaml with no flutter pin so resolution falls through to FVM.
        pubspecFile.writeAsStringSync('name: my_app\n');
      });

      group('when .fvmrc declares a pinned version', () {
        setUp(() {
          File(p.join(packageDir.path, '.fvmrc'))
              .writeAsStringSync('{"flutter": "3.24.0"}');
        });

        test('returns PinnedRevision from FVM config', () {
          expect(resolver.resolve(packageDir.path), isA<PinnedRevision>());
        });

        test('PinnedRevision carries the FVM version', () {
          final result = resolver.resolve(packageDir.path) as PinnedRevision;
          expect(result.version, equals(Version(3, 24, 0)));
        });

        test('logs the found FVM version', () {
          resolver.resolve(packageDir.path);
          expect(
            logMessages.any((m) => m.contains('3.24.0')),
            isTrue,
          );
        });
      });

      group('when .fvm/fvm_config.json declares a pinned version', () {
        setUp(() {
          final fvmDir = Directory(p.join(packageDir.path, '.fvm'))
            ..createSync();
          File(p.join(fvmDir.path, 'fvm_config.json'))
              .writeAsStringSync('{"flutterSdkVersion": "3.22.0"}');
        });

        test('returns PinnedRevision', () {
          expect(resolver.resolve(packageDir.path), isA<PinnedRevision>());
        });

        test('PinnedRevision carries the FVM version', () {
          final result = resolver.resolve(packageDir.path) as PinnedRevision;
          expect(result.version, equals(Version(3, 22, 0)));
        });
      });

      group('when FVM config is malformed', () {
        setUp(() {
          File(p.join(packageDir.path, '.fvmrc'))
              .writeAsStringSync('not json');
        });

        test('falls back to StableRevision', () {
          expect(resolver.resolve(packageDir.path), isA<StableRevision>());
        });

        test('logs an error', () {
          resolver.resolve(packageDir.path);
          expect(logMessages.any((m) => m.contains('Error')), isTrue);
        });
      });

      group('when FVM config has a channel name instead of a version', () {
        setUp(() {
          File(p.join(packageDir.path, '.fvmrc'))
              .writeAsStringSync('{"flutter": "stable"}');
        });

        test('falls back to StableRevision', () {
          expect(resolver.resolve(packageDir.path), isA<StableRevision>());
        });
      });
    });

    group('resolve', () {
      group('when no flutter version is pinned in pubspec.yaml', () {
        setUp(() {
          pubspecFile.writeAsStringSync('name: my_app\n');
        });

        test('returns StableRevision', () {
          expect(resolver.resolve(packageDir.path), isA<StableRevision>());
        });

        test('toVersionArg returns "stable"', () {
          expect(
            resolver.resolve(packageDir.path).toVersionArg(),
            equals('stable'),
          );
        });

        test('logs that stable channel will be used', () {
          resolver.resolve(packageDir.path);
          expect(logMessages.last, contains('stable'));
        });
      });

      group('when a pinned flutter version is in pubspec.yaml', () {
        setUp(() {
          pubspecFile.writeAsStringSync('''
environment:
  sdk: ^3.8.1
  flutter: 3.22.0
''');
        });

        test('returns PinnedRevision', () {
          expect(resolver.resolve(packageDir.path), isA<PinnedRevision>());
        });

        test('PinnedRevision carries the declared version', () {
          final result = resolver.resolve(packageDir.path) as PinnedRevision;
          expect(result.version, equals(Version(3, 22, 0)));
        });

        test('toVersionArg returns the version string', () {
          expect(
            resolver.resolve(packageDir.path).toVersionArg(),
            equals('3.22.0'),
          );
        });

        test('logs the found version', () {
          resolver.resolve(packageDir.path);
          expect(logMessages.any((m) => m.contains('3.22.0')), isTrue);
        });
      });

      group('when a version constraint is in pubspec.yaml', () {
        setUp(() {
          pubspecFile.writeAsStringSync('''
environment:
  sdk: ^3.8.1
  flutter: "^3.8.0"
''');
        });

        test('falls back to StableRevision', () {
          expect(resolver.resolve(packageDir.path), isA<StableRevision>());
        });

        test('logs the constraint and fallback', () {
          resolver.resolve(packageDir.path);
          expect(
            logMessages.any((m) => m.contains('^3.8.0')),
            isTrue,
          );
          expect(
            logMessages.any((m) => m.contains('stable')),
            isTrue,
          );
        });
      });

      group('when the package directory does not exist', () {
        test('falls back to StableRevision without throwing', () {
          expect(
            resolver.resolve(p.join(packageDir.path, 'nonexistent')),
            isA<StableRevision>(),
          );
        });

        test('logs an error message', () {
          resolver.resolve(p.join(packageDir.path, 'nonexistent'));
          expect(logMessages.any((m) => m.contains('Error')), isTrue);
        });
      });
    });
  });

  group(FlutterRevision, () {
    group('StableRevision', () {
      const revision = StableRevision();

      test('toVersionArg returns "stable"', () {
        expect(revision.toVersionArg(), equals('stable'));
      });

      test('toString returns "stable"', () {
        expect(revision.toString(), equals('stable'));
      });
    });

    group('PinnedRevision', () {
      final revision = PinnedRevision(Version(3, 22, 0));

      test('toVersionArg returns the version string', () {
        expect(revision.toVersionArg(), equals('3.22.0'));
      });

      test('toString returns the version string', () {
        expect(revision.toString(), equals('3.22.0'));
      });
    });
  });

  group(PubspecVersionConstraintException, () {
    const exception = PubspecVersionConstraintException(
      pubspecPath: '/some/path/pubspec.yaml',
      constraint: '^3.8.0',
    );

    test('toString includes the constraint', () {
      expect(exception.toString(), contains('^3.8.0'));
    });

    test('toString includes the path', () {
      expect(exception.toString(), contains('/some/path/pubspec.yaml'));
    });
  });
}
