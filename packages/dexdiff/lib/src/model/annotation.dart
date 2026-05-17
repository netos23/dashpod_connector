part of '../model.dart';

/// A single annotation with all pool references resolved.
///
/// Corresponds to an annotation_item in DEX format, combining a visibility
/// flag with an encoded_annotation.
@immutable
final class Annotation implements Comparable<Annotation> {
  const Annotation({
    required this.visibility,
    required this.typeDescriptor,
    required this.elements,
  });

  /// Annotation visibility: 0 = build, 1 = runtime, 2 = system.
  final int visibility;

  final String typeDescriptor;
  final Map<String, EncodedValue> elements;

  @override
  int compareTo(Annotation other) =>
      typeDescriptor.compareTo(other.typeDescriptor);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Annotation) return false;
    if (visibility != other.visibility) return false;
    if (typeDescriptor != other.typeDescriptor) return false;
    if (elements.length != other.elements.length) return false;
    for (final entry in elements.entries) {
      if (other.elements[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        visibility,
        typeDescriptor,
        Object.hashAll(
          elements.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

/// All annotations associated with a class — on the class itself, its fields,
/// methods, and method parameters.
///
/// All pool indices are resolved at parse time so two semantically identical
/// DEX files compare equal even when their string/type tables differ in order.
@immutable
final class AnnotationDirectory {
  const AnnotationDirectory({
    required this.classAnnotations,
    required this.fieldAnnotations,
    required this.methodAnnotations,
    required this.parameterAnnotations,
  });

  final List<Annotation> classAnnotations;
  final Map<String, List<Annotation>> fieldAnnotations;
  final Map<String, List<Annotation>> methodAnnotations;

  /// Per-parameter annotation sets, keyed by resolved method descriptor.
  /// Each value is a list of annotation sets, one per parameter.
  final Map<String, List<List<Annotation>>> parameterAnnotations;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnnotationDirectory) return false;
    if (!_sortedAnnotationListEquals(classAnnotations, other.classAnnotations)) {
      return false;
    }
    if (!_annotationMapEquals(fieldAnnotations, other.fieldAnnotations)) {
      return false;
    }
    if (!_annotationMapEquals(methodAnnotations, other.methodAnnotations)) {
      return false;
    }
    if (!_paramAnnotationMapEquals(
      parameterAnnotations,
      other.parameterAnnotations,
    )) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
        ...classAnnotations,
        ...fieldAnnotations.keys,
        ...methodAnnotations.keys,
        ...parameterAnnotations.keys,
      ]);
}

/// An embedded annotation as an encoded value.
///
/// Extends [EncodedValue] (sealed) — valid because this part belongs to the
/// same library as encoded_value.dart.
@immutable
final class AnnotationValue extends EncodedValue {
  const AnnotationValue(this.annotation);

  final Annotation annotation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnotationValue && annotation == other.annotation;

  @override
  int get hashCode => annotation.hashCode;
}

// -- Equality helpers -------------------------------------------------------

bool _sortedAnnotationListEquals(
  List<Annotation> a,
  List<Annotation> b,
) {
  if (a.length != b.length) return false;
  final aSorted = [...a]..sort();
  final bSorted = [...b]..sort();
  for (var i = 0; i < aSorted.length; i++) {
    if (aSorted[i] != bSorted[i]) return false;
  }
  return true;
}

bool _annotationMapEquals(
  Map<String, List<Annotation>> a,
  Map<String, List<Annotation>> b,
) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final bVal = b[entry.key];
    if (bVal == null) return false;
    if (!_sortedAnnotationListEquals(entry.value, bVal)) return false;
  }
  return true;
}

bool _paramAnnotationMapEquals(
  Map<String, List<List<Annotation>>> a,
  Map<String, List<List<Annotation>>> b,
) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final bVal = b[entry.key];
    if (bVal == null) return false;
    if (entry.value.length != bVal.length) return false;
    for (var i = 0; i < entry.value.length; i++) {
      if (!_sortedAnnotationListEquals(entry.value[i], bVal[i])) return false;
    }
  }
  return true;
}
