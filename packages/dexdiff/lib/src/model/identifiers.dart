part of '../model.dart';

/// A resolved prototype identifier (method signature).
@immutable
final class PrototypeId {
  const PrototypeId({
    required this.shorty,
    required this.returnType,
    required this.parameterTypes,
  });

  final String shorty;
  final String returnType;
  final List<String> parameterTypes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrototypeId &&
          shorty == other.shorty &&
          returnType == other.returnType &&
          _listEquals(parameterTypes, other.parameterTypes);

  @override
  int get hashCode =>
      Object.hash(shorty, returnType, Object.hashAll(parameterTypes));
}

/// A resolved field identifier.
@immutable
final class FieldId {
  const FieldId({
    required this.className,
    required this.typeName,
    required this.fieldName,
  });

  final String className;
  final String typeName;
  final String fieldName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldId &&
          className == other.className &&
          typeName == other.typeName &&
          fieldName == other.fieldName;

  @override
  int get hashCode => Object.hash(className, typeName, fieldName);
}

/// A resolved method identifier.
@immutable
final class MethodId {
  const MethodId({
    required this.className,
    required this.methodName,
    required this.proto,
  });

  final String className;
  final String methodName;
  final PrototypeId proto;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MethodId &&
          className == other.className &&
          methodName == other.methodName &&
          proto == other.proto;

  @override
  int get hashCode => Object.hash(className, methodName, proto);
}
