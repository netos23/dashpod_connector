/// The kind of semantic difference between two DEX files.
enum ChangeKind {
  /// Source file attribute changed. Safe — build path difference only.
  sourceFileChanged,

  classAdded,
  classRemoved,
  methodAdded,
  methodRemoved,
  fieldAdded,
  fieldRemoved,
  accessFlagsChanged,
  superclassChanged,
  interfacesChanged,
  bytecodeChanged,
  annotationsChanged,
  staticValuesChanged;

  /// Whether this kind of change does not affect runtime behaviour.
  bool get isSafe => this == ChangeKind.sourceFileChanged;
}

/// A single semantic difference found between two DEX files.
final class Change {
  const Change({required this.kind, required this.description});

  final ChangeKind kind;

  /// A human-readable description of this change.
  final String description;
}

/// The result of comparing two [DalvikExecutable]s.
final class DiffReport {
  const DiffReport({required this.changes});

  /// Creates an empty report representing identical files.
  const DiffReport.identical() : changes = const [];

  final List<Change> changes;

  Iterable<Change> get safeChanges => changes.where((c) => c.kind.isSafe);

  Iterable<Change> get breakingChanges =>
      changes.where((c) => !c.kind.isSafe);

  /// Whether all changes are safe to ignore.
  bool get isSafe => breakingChanges.isEmpty;

  /// A human-readable summary formatted for display.
  String describe() {
    final safe = safeChanges.toList();
    final breaking = breakingChanges.toList();
    final buf = StringBuffer();

    if (safe.isNotEmpty) {
      buf.writeln('Safe differences (${safe.length}):');
      for (final c in safe) {
        buf.writeln('  - ${c.description}');
      }
    }

    if (breaking.isNotEmpty) {
      buf.writeln('Breaking differences (${breaking.length}):');
      for (final c in breaking) {
        buf.writeln('  - ${c.description}');
      }
    }

    return buf.toString().trimRight();
  }
}
