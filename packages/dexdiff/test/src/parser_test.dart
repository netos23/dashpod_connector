// cspell:words Lcom Ljava
import 'dart:io';
import 'dart:typed_data';

import 'package:dexdiff/dexdiff.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group(DalvikParser, () {
    const parser = DalvikParser();

    final fixturesPath = p.join('test', 'fixtures', 'dex');

    late Uint8List baseBytes;

    setUp(() {
      baseBytes = File(p.join(fixturesPath, 'base.dex')).readAsBytesSync();
    });

    group('parse', () {
      test('parses a valid DEX file', () {
        final exe = parser.parse(baseBytes);
        expect(exe.strings, hasLength(13));
        expect(exe.typeDescriptors, hasLength(5));
        expect(exe.protoIds, hasLength(2));
        expect(exe.fieldIds, hasLength(2));
        expect(exe.methodIds, hasLength(3));
        expect(exe.classDefs, hasLength(2));
      });

      test('resolves string table values', () {
        final exe = parser.parse(baseBytes);
        expect(exe.strings, contains('<init>'));
        expect(exe.strings, contains('Lcom/example/MyClass;'));
        expect(exe.strings, contains('Ljava/lang/Object;'));
        expect(exe.strings, contains('myField'));
        expect(exe.strings, contains('getValue'));
      });

      test('resolves type descriptors', () {
        final exe = parser.parse(baseBytes);
        expect(exe.typeDescriptors, contains('I'));
        expect(exe.typeDescriptors, contains('V'));
        expect(exe.typeDescriptors, contains('Lcom/example/MyClass;'));
        expect(exe.typeDescriptors, contains('Lcom/example/Helper;'));
        expect(exe.typeDescriptors, contains('Ljava/lang/Object;'));
      });

      test('resolves field identifiers', () {
        final exe = parser.parse(baseBytes);

        final value = exe.fieldIds.firstWhere((f) => f.fieldName == 'value');
        expect(value.className, equals('Lcom/example/Helper;'));
        expect(value.typeName, equals('I'));

        final myField = exe.fieldIds.firstWhere((f) => f.fieldName == 'myField');
        expect(myField.className, equals('Lcom/example/MyClass;'));
        expect(myField.typeName, equals('I'));
      });

      test('resolves method identifiers', () {
        final exe = parser.parse(baseBytes);
        final getValue = exe.methodIds.firstWhere(
          (m) => m.methodName == 'getValue',
        );
        expect(getValue.className, equals('Lcom/example/Helper;'));
        expect(getValue.proto.returnType, equals('I'));
        expect(getValue.proto.parameterTypes, isEmpty);
      });

      test('resolves class definitions', () {
        final exe = parser.parse(baseBytes);
        final myClass = exe.classDefs.firstWhere(
          (c) => c.className == 'Lcom/example/MyClass;',
        );
        expect(myClass.accessFlags, equals(1));
        expect(myClass.superclass, equals('Ljava/lang/Object;'));
        expect(myClass.interfaces, isEmpty);
        expect(myClass.sourceFile, equals('MyClass.java'));
        expect(myClass.body, isNotNull);
        expect(myClass.body!.instanceFields, hasLength(1));
        expect(myClass.body!.directMethods, hasLength(1));
      });

      test('resolves class body fields and methods', () {
        final exe = parser.parse(baseBytes);
        final helper = exe.classDefs.firstWhere(
          (c) => c.className == 'Lcom/example/Helper;',
        );
        expect(helper.body, isNotNull);
        expect(helper.body!.instanceFields, hasLength(1));
        expect(helper.body!.instanceFields[0].field.fieldName, equals('value'));
        expect(helper.body!.directMethods, hasLength(1));
        expect(
          helper.body!.directMethods[0].method.methodName,
          equals('<init>'),
        );
        expect(helper.body!.virtualMethods, hasLength(1));
        expect(
          helper.body!.virtualMethods[0].method.methodName,
          equals('getValue'),
        );
      });

      test('parses method code items', () {
        final exe = parser.parse(
          File(p.join(fixturesPath, 'base_with_code.dex')).readAsBytesSync(),
        );
        final method = exe.classDefs[0].body!.directMethods[0];
        expect(method.code, isA<MethodCode>());
        expect(method.code!.registersSize, isNonZero);
      });

      test('MethodCode has expected field values', () {
        final exe = parser.parse(
          File(p.join(fixturesPath, 'base_with_code.dex')).readAsBytesSync(),
        );
        final code = exe.classDefs[0].body!.directMethods[0].code!;
        expect(code.registersSize, equals(1));
        expect(code.insSize, equals(1));
        expect(code.outsSize, equals(0));
        expect(code.canonicalBytecode, isNotEmpty);
      });

      test('annotations and staticValues are null in base fixture', () {
        final exe = parser.parse(baseBytes);
        for (final def in exe.classDefs) {
          expect(def.annotations, isNull);
          expect(def.staticValues, isNull);
        }
      });
    });

    group('error handling', () {
      test('throws FormatException for truncated input', () {
        expect(
          () => parser.parse(Uint8List.fromList([0x64, 0x65, 0x78])),
          throwsFormatException,
        );
      });

      test('throws FormatException for invalid magic bytes', () {
        expect(
          () => parser.parse(Uint8List(112)),
          throwsFormatException,
        );
      });
    });
  });
}
