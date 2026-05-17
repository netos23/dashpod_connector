import '../model.dart';
import 'change.dart';

/// Compares two parsed [DalvikExecutable]s and produces a [DiffReport]
/// describing their semantic differences.
///
/// Stateless — a single instance can be reused across multiple diff calls.
final class DalvikDiffer {
  const DalvikDiffer();

  DiffReport diff(DalvikExecutable baseline, DalvikExecutable candidate) {
    final changes = <Change>[];

    final baseClasses = {for (final c in baseline.classDefs) c.className: c};
    final candClasses = {
      for (final c in candidate.classDefs) c.className: c,
    };

    final baseNames = baseClasses.keys.toSet();
    final candNames = candClasses.keys.toSet();

    for (final added in candNames.difference(baseNames)) {
      changes.add(Change(kind: ChangeKind.classAdded, description: 'Class added: $added'));
    }

    for (final removed in baseNames.difference(candNames)) {
      changes.add(
        Change(kind: ChangeKind.classRemoved, description: 'Class removed: $removed'),
      );
    }

    final matched = baseNames.intersection(candNames);

    for (final name in matched) {
      _compareStructure(baseClasses[name]!, candClasses[name]!, changes);
    }

    // Skip deep comparison when structural changes are already breaking — the
    // caller will see breaking regardless.
    if (changes.any((c) => !c.kind.isSafe)) {
      return DiffReport(changes: changes);
    }

    for (final name in matched) {
      _compareData(name, baseClasses[name]!, candClasses[name]!, changes);
    }

    return DiffReport(changes: changes);
  }

  // -- Per-class structural comparison -------------------------------------

  void _compareStructure(
    ClassDefinition base,
    ClassDefinition cand,
    List<Change> changes,
  ) {
    final name = base.className;

    if (base.sourceFile != cand.sourceFile) {
      changes.add(
        Change(
          kind: ChangeKind.sourceFileChanged,
          description:
              '$name: source file changed from '
              '"${base.sourceFile}" to "${cand.sourceFile}"',
        ),
      );
    }

    if (base.accessFlags != cand.accessFlags) {
      changes.add(
        Change(
          kind: ChangeKind.accessFlagsChanged,
          description:
              '$name: class access flags changed from '
              '0x${base.accessFlags.toRadixString(16)} to '
              '0x${cand.accessFlags.toRadixString(16)}',
        ),
      );
    }

    if (base.superclass != cand.superclass) {
      changes.add(
        Change(
          kind: ChangeKind.superclassChanged,
          description:
              '$name: superclass changed from '
              '${base.superclass} to ${cand.superclass}',
        ),
      );
    }

    if (!_listEquals(base.interfaces, cand.interfaces)) {
      changes.add(
        Change(kind: ChangeKind.interfacesChanged, description: '$name: interfaces changed'),
      );
    }

    _compareMembers(
      className: name,
      baseBody: base.body,
      candBody: cand.body,
      extract: (body) => {
        for (final f in [...body.staticFields, ...body.instanceFields])
          '${f.field.className}.${f.field.fieldName}:${f.field.typeName}':
              f.accessFlags,
      },
      memberLabel: 'field',
      addedKind: ChangeKind.fieldAdded,
      removedKind: ChangeKind.fieldRemoved,
      changes: changes,
    );

    _compareMembers(
      className: name,
      baseBody: base.body,
      candBody: cand.body,
      extract: (body) => {
        for (final m in [...body.directMethods, ...body.virtualMethods])
          _methodKey(m): m.accessFlags,
      },
      memberLabel: 'method',
      addedKind: ChangeKind.methodAdded,
      removedKind: ChangeKind.methodRemoved,
      changes: changes,
    );
  }

  void _compareMembers({
    required String className,
    required ClassBody? baseBody,
    required ClassBody? candBody,
    required Map<String, int> Function(ClassBody) extract,
    required String memberLabel,
    required ChangeKind addedKind,
    required ChangeKind removedKind,
    required List<Change> changes,
  }) {
    final baseMembers =
        baseBody != null ? extract(baseBody) : <String, int>{};
    final candMembers =
        candBody != null ? extract(candBody) : <String, int>{};

    final baseKeys = baseMembers.keys.toSet();
    final candKeys = candMembers.keys.toSet();

    for (final added in candKeys.difference(baseKeys)) {
      changes.add(
        Change(
          kind: addedKind,
          description: '$className: $memberLabel added: $added',
        ),
      );
    }

    for (final removed in baseKeys.difference(candKeys)) {
      changes.add(
        Change(
          kind: removedKind,
          description: '$className: $memberLabel removed: $removed',
        ),
      );
    }

    for (final key in baseKeys.intersection(candKeys)) {
      if (baseMembers[key] != candMembers[key]) {
        changes.add(
          Change(
            kind: ChangeKind.accessFlagsChanged,
            description:
                '$className: $memberLabel $key access flags changed from '
                '0x${baseMembers[key]!.toRadixString(16)} to '
                '0x${candMembers[key]!.toRadixString(16)}',
          ),
        );
      }
    }
  }

  // -- Per-class data (bytecode, annotations, static values) comparison ----

  void _compareData(
    String className,
    ClassDefinition base,
    ClassDefinition cand,
    List<Change> changes,
  ) {
    _compareBytecode(className, base, cand, changes);
    _compareAnnotations(className, base, cand, changes);
    _compareStaticValues(className, base, cand, changes);
  }

  void _compareBytecode(
    String className,
    ClassDefinition base,
    ClassDefinition cand,
    List<Change> changes,
  ) {
    final baseMethods = _methodMap(base.body);
    final candMethods = _methodMap(cand.body);

    for (final entry in baseMethods.entries) {
      final candMethod = candMethods[entry.key];
      if (candMethod == null) continue; // caught structurally

      if (!_codeEquals(entry.value.code, candMethod.code)) {
        changes.add(
          Change(
            kind: ChangeKind.bytecodeChanged,
            description: '$className: bytecode changed in ${entry.key}',
          ),
        );
      }
    }
  }

  void _compareAnnotations(
    String className,
    ClassDefinition base,
    ClassDefinition cand,
    List<Change> changes,
  ) {
    if (base.annotations == cand.annotations) return;
    if (base.annotations == null || cand.annotations == null) {
      changes.add(
        Change(
          kind: ChangeKind.annotationsChanged,
          description: '$className: annotations added or removed',
        ),
      );
      return;
    }
    changes.add(
      Change(
        kind: ChangeKind.annotationsChanged,
        description: '$className: annotations changed',
      ),
    );
  }

  void _compareStaticValues(
    String className,
    ClassDefinition base,
    ClassDefinition cand,
    List<Change> changes,
  ) {
    if (_nullableListEquals(base.staticValues, cand.staticValues)) return;
    if (base.staticValues == null || cand.staticValues == null) {
      changes.add(
        Change(
          kind: ChangeKind.staticValuesChanged,
          description: '$className: static field initial values added or removed',
        ),
      );
      return;
    }
    changes.add(
      Change(
        kind: ChangeKind.staticValuesChanged,
        description: '$className: static field initial values changed',
      ),
    );
  }

  // -- Utility -------------------------------------------------------------

  static String _methodKey(MethodEntry m) {
    final params = m.method.proto.parameterTypes.join(', ');
    return '${m.method.className}.${m.method.methodName}'
        '($params)${m.method.proto.returnType}';
  }

  static Map<String, MethodEntry> _methodMap(ClassBody? body) {
    if (body == null) return const {};
    return {
      for (final m in [...body.directMethods, ...body.virtualMethods])
        _methodKey(m): m,
    };
  }

  static bool _codeEquals(MethodCode? a, MethodCode? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.registersSize == b.registersSize &&
        a.insSize == b.insSize &&
        a.outsSize == b.outsSize &&
        a.canonicalBytecode == b.canonicalBytecode;
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _nullableListEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return _listEquals(a, b);
  }
}
