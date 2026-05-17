part of '../model.dart';

/// A fully parsed Dalvik Executable (DEX) file.
///
/// All pool indices are resolved to their string/type/identifier values at
/// parse time, so comparisons do not require knowledge of index remapping.
@immutable
final class DalvikExecutable {
  const DalvikExecutable({
    required this.header,
    required this.strings,
    required this.typeDescriptors,
    required this.protoIds,
    required this.fieldIds,
    required this.methodIds,
    required this.classDefs,
  });

  final ExecutableHeader header;

  /// Resolved string table.
  final List<String> strings;

  /// Resolved type descriptors (e.g. `Ljava/lang/Object;`, `I`, `V`).
  final List<String> typeDescriptors;

  final List<PrototypeId> protoIds;
  final List<FieldId> fieldIds;
  final List<MethodId> methodIds;
  final List<ClassDefinition> classDefs;
}
