part of '../model.dart';

/// A value from the DEX encoded_value format with all pool indices resolved.
///
/// The DEX format encodes annotation element values, static field initializers,
/// and other constant data as a tagged union. This sealed hierarchy mirrors
/// those tags with proper Dart types.
@immutable
sealed class EncodedValue {
  const EncodedValue();
}

/// A primitive numeric value stored as its raw integer representation.
///
/// Covers DEX value types: byte (0x00), short (0x02), char (0x03),
/// int (0x04), long (0x06), float (0x10), double (0x11).
@immutable
final class PrimitiveValue extends EncodedValue {
  const PrimitiveValue({required this.typeTag, required this.value});

  final int typeTag;
  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrimitiveValue &&
          typeTag == other.typeTag &&
          value == other.value;

  @override
  int get hashCode => Object.hash(typeTag, value);
}

/// A resolved string from the string pool.
@immutable
final class StringValue extends EncodedValue {
  const StringValue(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StringValue && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// A resolved type descriptor (e.g. `Ljava/lang/String;`).
@immutable
final class TypeValue extends EncodedValue {
  const TypeValue(this.descriptor);

  final String descriptor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeValue && descriptor == other.descriptor;

  @override
  int get hashCode => descriptor.hashCode;
}

/// A resolved field reference (as an encoded value in annotations or
/// static initializers).
@immutable
final class FieldRefValue extends EncodedValue {
  const FieldRefValue(this.field);

  final FieldId field;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FieldRefValue && field == other.field;

  @override
  int get hashCode => field.hashCode;
}

/// A resolved method reference (as an encoded value in annotations or
/// static initializers).
@immutable
final class MethodRefValue extends EncodedValue {
  const MethodRefValue(this.method);

  final MethodId method;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MethodRefValue && method == other.method;

  @override
  int get hashCode => method.hashCode;
}

/// A resolved enum constant. Backed by a field reference in DEX format.
@immutable
final class EnumValue extends EncodedValue {
  const EnumValue(this.field);

  final FieldId field;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EnumValue && field == other.field;

  @override
  int get hashCode => field.hashCode;
}

/// A resolved method type (prototype) reference.
@immutable
final class MethodTypeValue extends EncodedValue {
  const MethodTypeValue(this.proto);

  final PrototypeId proto;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MethodTypeValue && proto == other.proto;

  @override
  int get hashCode => proto.hashCode;
}

/// A method handle index. The method_handle pool is not parsed, so only
/// the raw index is retained.
@immutable
final class MethodHandleValue extends EncodedValue {
  const MethodHandleValue(this.index);

  final int index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MethodHandleValue && index == other.index;

  @override
  int get hashCode => index.hashCode;
}

/// An array of encoded values.
@immutable
final class ArrayValue extends EncodedValue {
  const ArrayValue(this.elements);

  final List<EncodedValue> elements;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrayValue && _listEquals(elements, other.elements);

  @override
  int get hashCode => Object.hashAll(elements);
}

/// An embedded annotation value (defined in annotation.dart — same library).
// AnnotationValue is declared in annotation.dart as a part of this library.
// It extends EncodedValue (sealed) because it is in the same library.

/// The null value.
@immutable
final class NullValue extends EncodedValue {
  const NullValue();

  @override
  bool operator ==(Object other) => other is NullValue;

  @override
  int get hashCode => 0;
}

/// A boolean value.
@immutable
final class BoolValue extends EncodedValue {
  const BoolValue({required this.value});

  final bool value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BoolValue && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
