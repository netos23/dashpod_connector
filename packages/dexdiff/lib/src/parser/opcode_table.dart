// cspell:disable

/// The pool kind referenced by an instruction operand.
enum PoolKind {
  string,
  type,
  field,
  method,
  proto,
  callSite,
  methodHandle,
}

/// A pool-index reference within a DEX instruction.
final class PoolRef {
  const PoolRef(this.unitOffset, this.pool, {this.is32Bit = false});

  /// The 16-bit code-unit offset (within the instruction) that holds the
  /// index.
  final int unitOffset;
  final PoolKind pool;

  /// True for instructions where the index spans two consecutive units
  /// (lower unit followed by upper unit).
  final bool is32Bit;
}

/// Describes which code units within an instruction carry pool-index
/// references.
final class InstructionIndexInfo {
  const InstructionIndexInfo(this.refs);

  final List<PoolRef> refs;

  /// Returns the [PoolRef] at [unitOffset], or null if that unit is not
  /// a pool reference.
  PoolRef? refAt(int unitOffset) {
    for (final r in refs) {
      if (r.unitOffset == unitOffset) return r;
    }
    return null;
  }
}

/// Instruction sizes in 16-bit code units, indexed by opcode byte.
///
/// Derived from the Dalvik bytecode instruction formats table at
/// https://source.android.com/docs/core/runtime/instruction-formats
/// and the opcode-to-format mapping at
/// https://source.android.com/docs/core/runtime/dalvik-bytecode
const opcodeSizes = [
  1, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 1, 1, 1, 1, 1, // 0x00-0x0f
  1, 1, 1, 2, 3, 2, 2, 3, 5, 2, 2, 3, 2, 1, 1, 2, // 0x10-0x1f
  2, 1, 2, 2, 3, 3, 3, 1, 1, 2, 3, 3, 3, 2, 2, 2, // 0x20-0x2f
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, // 0x30-0x3f
  1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, // 0x40-0x4f
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, // 0x50-0x5f
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, // 0x60-0x6f
  3, 3, 3, 1, 3, 3, 3, 3, 3, 1, 1, 1, 1, 1, 1, 1, // 0x70-0x7f
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, // 0x80-0x8f
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, // 0x90-0x9f
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, // 0xa0-0xaf
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, // 0xb0-0xbf
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, // 0xc0-0xcf
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, // 0xd0-0xdf
  2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, // 0xe0-0xef
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 4, 3, 3, 2, 2, // 0xf0-0xff
];

Map<int, InstructionIndexInfo> _rangeInfo(int start, int end, PoolKind pool) =>
    {
      for (var op = start; op <= end; op++)
        op: InstructionIndexInfo([PoolRef(1, pool)]),
    };

/// Opcodes that carry pool-index references, indexed by opcode byte.
///
/// Only opcodes that reference a pool (string@, type@, field@, method@,
/// proto@, call_site@, method_handle@) have entries here.
final opcodeIndexInfo = <int, InstructionIndexInfo>{
  // const-string (string@)
  0x1a: const InstructionIndexInfo([PoolRef(1, PoolKind.string)]),
  // const-string/jumbo (string@, 32-bit)
  0x1b: const InstructionIndexInfo([
    PoolRef(1, PoolKind.string, is32Bit: true),
  ]),
  // const-class (type@)
  0x1c: const InstructionIndexInfo([PoolRef(1, PoolKind.type)]),
  // check-cast (type@)
  0x1f: const InstructionIndexInfo([PoolRef(1, PoolKind.type)]),
  // instance-of (type@)
  0x20: const InstructionIndexInfo([PoolRef(1, PoolKind.type)]),
  // new-instance (type@)
  0x22: const InstructionIndexInfo([PoolRef(1, PoolKind.type)]),
  // new-array (type@)
  0x23: const InstructionIndexInfo([PoolRef(1, PoolKind.type)]),
  // filled-new-array (type@)
  0x24: const InstructionIndexInfo([PoolRef(1, PoolKind.type)]),
  // filled-new-array/range (type@)
  0x25: const InstructionIndexInfo([PoolRef(1, PoolKind.type)]),
  // iget/iput 0x52-0x5f (field@)
  ..._rangeInfo(0x52, 0x5f, PoolKind.field),
  // sget/sput 0x60-0x6d (field@)
  ..._rangeInfo(0x60, 0x6d, PoolKind.field),
  // invoke-virtual .. invoke-interface 0x6e-0x72 (method@)
  ..._rangeInfo(0x6e, 0x72, PoolKind.method),
  // invoke-virtual/range .. invoke-interface/range 0x74-0x78 (method@)
  ..._rangeInfo(0x74, 0x78, PoolKind.method),
  // invoke-polymorphic (method@ + proto@)
  0xfa: const InstructionIndexInfo([
    PoolRef(1, PoolKind.method),
    PoolRef(3, PoolKind.proto),
  ]),
  // invoke-polymorphic/range (method@ + proto@)
  0xfb: const InstructionIndexInfo([
    PoolRef(1, PoolKind.method),
    PoolRef(3, PoolKind.proto),
  ]),
  // invoke-custom (call_site@)
  0xfc: const InstructionIndexInfo([PoolRef(1, PoolKind.callSite)]),
  // invoke-custom/range (call_site@)
  0xfd: const InstructionIndexInfo([PoolRef(1, PoolKind.callSite)]),
  // const-method-handle (method_handle@)
  0xfe: const InstructionIndexInfo([PoolRef(1, PoolKind.methodHandle)]),
  // const-method-type (proto@)
  0xff: const InstructionIndexInfo([PoolRef(1, PoolKind.proto)]),
};
