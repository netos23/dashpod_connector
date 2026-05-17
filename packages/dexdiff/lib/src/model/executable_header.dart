part of '../model.dart';

/// The header section of a DEX file.
@immutable
final class ExecutableHeader {
  const ExecutableHeader({
    required this.stringIdsSize,
    required this.stringIdsOff,
    required this.typeIdsSize,
    required this.typeIdsOff,
    required this.protoIdsSize,
    required this.protoIdsOff,
    required this.fieldIdsSize,
    required this.fieldIdsOff,
    required this.methodIdsSize,
    required this.methodIdsOff,
    required this.classDefsSize,
    required this.classDefsOff,
  });

  final int stringIdsSize;
  final int stringIdsOff;
  final int typeIdsSize;
  final int typeIdsOff;
  final int protoIdsSize;
  final int protoIdsOff;
  final int fieldIdsSize;
  final int fieldIdsOff;
  final int methodIdsSize;
  final int methodIdsOff;
  final int classDefsSize;
  final int classDefsOff;
}
