part of '../model.dart';

/// A resolved class definition.
@immutable
final class ClassDefinition {
  const ClassDefinition({
    required this.className,
    required this.accessFlags,
    required this.superclass,
    required this.interfaces,
    required this.sourceFile,
    required this.annotations,
    required this.staticValues,
    required this.body,
  });

  final String className;
  final int accessFlags;

  /// Type descriptor of the superclass, or `null` for `java/lang/Object`.
  final String? superclass;

  /// Type descriptors of implemented interfaces.
  final List<String> interfaces;

  /// Source file name, or `null` if not present.
  final String? sourceFile;

  /// Parsed annotation directory, or `null` if the class has none.
  final AnnotationDirectory? annotations;

  /// Parsed static field initial values, or `null` if none.
  final List<EncodedValue>? staticValues;

  /// Fields and methods, or `null` if the class has no data.
  final ClassBody? body;
}

/// The fields and methods of a class.
@immutable
final class ClassBody {
  const ClassBody({
    required this.staticFields,
    required this.instanceFields,
    required this.directMethods,
    required this.virtualMethods,
  });

  final List<FieldEntry> staticFields;
  final List<FieldEntry> instanceFields;

  /// Static, private, and constructor methods.
  final List<MethodEntry> directMethods;

  final List<MethodEntry> virtualMethods;
}

/// A field definition within a class.
@immutable
final class FieldEntry {
  const FieldEntry({required this.field, required this.accessFlags});

  final FieldId field;
  final int accessFlags;
}

/// A method definition within a class.
@immutable
final class MethodEntry {
  const MethodEntry({
    required this.method,
    required this.accessFlags,
    required this.code,
  });

  final MethodId method;
  final int accessFlags;

  /// Parsed code, or `null` if the method is abstract or native.
  final MethodCode? code;
}

/// A parsed code_item from a DEX file with all pool indices resolved.
@immutable
final class MethodCode {
  const MethodCode({
    required this.registersSize,
    required this.insSize,
    required this.outsSize,
    required this.canonicalBytecode,
  });

  final int registersSize;
  final int insSize;
  final int outsSize;

  /// Canonical string of instructions and try/catch with all pool indices
  /// resolved to their string values. Used for bytecode comparison without
  /// worrying about index remapping when string tables shift.
  final String canonicalBytecode;
}
