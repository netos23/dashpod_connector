// cspell:words Lcom Ljava
import 'dart:io';

import 'package:dexdiff/dexdiff.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group(DalvikDiffer, () {
    const parser = DalvikParser();
    const differ = DalvikDiffer();

    final fixturesPath = p.join('test', 'fixtures', 'dex');

    late DalvikExecutable baseDex;

    setUp(() {
      baseDex = parser.parse(
        File(p.join(fixturesPath, 'base.dex')).readAsBytesSync(),
      );
    });

    DalvikExecutable parseFixture(String name) => parser.parse(
          File(p.join(fixturesPath, name)).readAsBytesSync(),
        );

    test('identical files produce empty report', () {
      final report = differ.diff(baseDex, baseDex);
      expect(report.safeChanges, isEmpty);
      expect(report.breakingChanges, isEmpty);
      expect(report.isSafe, isTrue);
    });

    test('path-only difference is classified as safe', () {
      final pathDex = parseFixture('path_only_diff.dex');
      final report = differ.diff(baseDex, pathDex);
      expect(report.safeChanges, isNotEmpty);
      expect(report.breakingChanges, isEmpty);
      expect(report.isSafe, isTrue);
      expect(
        report.safeChanges.every((c) => c.kind == ChangeKind.sourceFileChanged),
        isTrue,
      );
    });

    test('added method is classified as breaking', () {
      final report = differ.diff(baseDex, parseFixture('method_added.dex'));
      expect(report.isSafe, isFalse);
      expect(
        report.breakingChanges.any((c) => c.kind == ChangeKind.methodAdded),
        isTrue,
      );
    });

    test('removed field is classified as breaking', () {
      final report = differ.diff(baseDex, parseFixture('field_removed.dex'));
      expect(report.isSafe, isFalse);
      expect(
        report.breakingChanges.any((c) => c.kind == ChangeKind.fieldRemoved),
        isTrue,
      );
    });

    test('changed superclass is classified as breaking', () {
      final report =
          differ.diff(baseDex, parseFixture('superclass_changed.dex'));
      expect(report.isSafe, isFalse);
      expect(
        report.breakingChanges.any((c) => c.kind == ChangeKind.superclassChanged),
        isTrue,
      );
    });

    test('mixed safe and breaking changes are not safe overall', () {
      final report =
          differ.diff(baseDex, parseFixture('superclass_changed.dex'));
      expect(report.isSafe, isFalse);
    });

    group('bytecode comparison', () {
      late DalvikExecutable baseWithCode;

      setUp(() {
        baseWithCode = parseFixture('base_with_code.dex');
      });

      test('identical bytecode is safe', () {
        final report = differ.diff(baseWithCode, baseWithCode);
        expect(report.isSafe, isTrue);
      });

      test('changed bytecode is breaking', () {
        final report =
            differ.diff(baseWithCode, parseFixture('code_changed.dex'));
        expect(report.isSafe, isFalse);
        expect(
          report.breakingChanges
              .any((c) => c.kind == ChangeKind.bytecodeChanged),
          isTrue,
        );
      });

      test('path-only diff with identical bytecode is safe', () {
        final report =
            differ.diff(baseWithCode, parseFixture('path_only_with_code.dex'));
        expect(report.isSafe, isTrue);
        expect(report.safeChanges, isNotEmpty);
      });
    });

    group('describe', () {
      test('formats safe-only changes', () {
        final report = differ.diff(baseDex, parseFixture('path_only_diff.dex'));
        final text = report.describe();
        expect(text, contains('Safe differences'));
        expect(text, contains('source file changed'));
        expect(text, isNot(contains('Breaking differences')));
      });

      test('formats breaking changes', () {
        final report =
            differ.diff(baseDex, parseFixture('method_added.dex'));
        final text = report.describe();
        expect(text, contains('Breaking differences'));
        expect(text, contains('method added'));
      });

      test('empty report produces empty string', () {
        expect(differ.diff(baseDex, baseDex).describe(), isEmpty);
      });

      test('path-only diff produces exact output', () {
        final report = differ.diff(baseDex, parseFixture('path_only_diff.dex'));
        expect(
          report.describe(),
          equals(
            'Safe differences (2):\n'
            '  - Lcom/example/Helper;: source file changed from '
            '"Helper.java" to "/different/path/Helper.java"\n'
            '  - Lcom/example/MyClass;: source file changed from '
            '"MyClass.java" to "/different/path/MyClass.java"',
          ),
        );
      });

      test('method-added diff produces exact output', () {
        final report =
            differ.diff(baseDex, parseFixture('method_added.dex'));
        expect(
          report.describe(),
          equals(
            'Breaking differences (1):\n'
            '  - Lcom/example/MyClass;: method added: '
            'Lcom/example/MyClass;.newMethod()V',
          ),
        );
      });

      test('bytecode-changed diff produces exact output', () {
        final baseWithCode = parseFixture('base_with_code.dex');
        final report =
            differ.diff(baseWithCode, parseFixture('code_changed.dex'));
        expect(
          report.describe(),
          equals(
            'Breaking differences (1):\n'
            '  - Lcom/example/Foo;: bytecode changed in '
            'Lcom/example/Foo;.<init>()V',
          ),
        );
      });
    });

    group('DiffReport.identical', () {
      test('creates an empty safe report', () {
        const report = DiffReport.identical();
        expect(report.safeChanges, isEmpty);
        expect(report.breakingChanges, isEmpty);
        expect(report.isSafe, isTrue);
      });
    });

    group('ChangeKind.isSafe', () {
      test('sourceFileChanged is safe', () {
        expect(ChangeKind.sourceFileChanged.isSafe, isTrue);
      });

      for (final kind in ChangeKind.values.where(
        (k) => k != ChangeKind.sourceFileChanged,
      )) {
        test('$kind is not safe', () {
          expect(kind.isSafe, isFalse);
        });
      }
    });
  });
}
