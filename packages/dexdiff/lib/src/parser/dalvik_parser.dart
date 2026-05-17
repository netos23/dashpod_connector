// cspell:words mutf uleb sleb
import 'dart:typed_data';

import '../model.dart';
import 'binary_cursor.dart';
import 'opcode_table.dart';

/// Sentinel index value meaning "no entry" in DEX tables.
const _noIndex = 0xFFFFFFFF;

/// DEX file magic prefix ("dex\n").
const _dexMagicPrefix = [0x64, 0x65, 0x78, 0x0a];

/// Parses DEX binary files into structured [DalvikExecutable] objects.
///
/// Stateless — a single instance can be reused across multiple parse calls.
/// See https://source.android.com/docs/core/runtime/dex-format for the spec.
final class DalvikParser {
  const DalvikParser();

  /// Parses a DEX file from raw bytes.
  ///
  /// Throws [FormatException] if [bytes] is not a valid DEX file.
  DalvikExecutable parse(Uint8List bytes) {
    _validateMagic(bytes);

    final header = _parseHeader(bytes);
    final strings = _parseStrings(bytes, header);
    final typeDescriptors = _parseTypeDescriptors(bytes, header, strings);
    final protoIds = _parseProtoIds(bytes, header, strings, typeDescriptors);
    final fieldIds = _parseFieldIds(bytes, header, strings, typeDescriptors);
    final methodIds = _parseMethodIds(
      bytes,
      header,
      strings,
      typeDescriptors,
      protoIds,
    );
    final classDefs = _parseClassDefs(
      bytes,
      header,
      strings,
      typeDescriptors,
      protoIds,
      fieldIds,
      methodIds,
    );

    return DalvikExecutable(
      header: header,
      strings: strings,
      typeDescriptors: typeDescriptors,
      protoIds: protoIds,
      fieldIds: fieldIds,
      methodIds: methodIds,
      classDefs: classDefs,
    );
  }

  // -- Validation -----------------------------------------------------------

  void _validateMagic(Uint8List bytes) {
    if (bytes.length < 112) {
      throw FormatException(
        'File too small to be a DEX file (${bytes.length} bytes)',
      );
    }
    for (var i = 0; i < _dexMagicPrefix.length; i++) {
      if (bytes[i] != _dexMagicPrefix[i]) {
        throw const FormatException('Invalid DEX magic bytes');
      }
    }
  }

  // -- Section parsers ------------------------------------------------------

  ExecutableHeader _parseHeader(Uint8List bytes) {
    // Header fields begin at offset 56 (after magic, checksum, SHA-1,
    // file_size, header_size, endian_tag).
    final c = BinaryCursor(bytes, offset: 56);
    return ExecutableHeader(
      stringIdsSize: c.readUint32(),
      stringIdsOff: c.readUint32(),
      typeIdsSize: c.readUint32(),
      typeIdsOff: c.readUint32(),
      protoIdsSize: c.readUint32(),
      protoIdsOff: c.readUint32(),
      fieldIdsSize: c.readUint32(),
      fieldIdsOff: c.readUint32(),
      methodIdsSize: c.readUint32(),
      methodIdsOff: c.readUint32(),
      classDefsSize: c.readUint32(),
      classDefsOff: c.readUint32(),
    );
  }

  List<String> _parseStrings(Uint8List bytes, ExecutableHeader header) {
    final c = BinaryCursor(bytes, offset: header.stringIdsOff);
    return [
      for (var i = 0; i < header.stringIdsSize; i++)
        _readMutf8String(c.fork(c.readUint32())),
    ];
  }

  List<String> _parseTypeDescriptors(
    Uint8List bytes,
    ExecutableHeader header,
    List<String> strings,
  ) {
    final c = BinaryCursor(bytes, offset: header.typeIdsOff);
    return [
      for (var i = 0; i < header.typeIdsSize; i++) strings[c.readUint32()],
    ];
  }

  List<PrototypeId> _parseProtoIds(
    Uint8List bytes,
    ExecutableHeader header,
    List<String> strings,
    List<String> types,
  ) {
    final c = BinaryCursor(bytes, offset: header.protoIdsOff);
    final protos = <PrototypeId>[];
    for (var i = 0; i < header.protoIdsSize; i++) {
      final shortyIdx = c.readUint32();
      final returnTypeIdx = c.readUint32();
      final parametersOff = c.readUint32();

      final paramTypes = <String>[];
      if (parametersOff != 0) {
        final pc = c.fork(parametersOff);
        final count = pc.readUint32();
        for (var j = 0; j < count; j++) {
          paramTypes.add(types[pc.readUint16()]);
        }
      }

      protos.add(
        PrototypeId(
          shorty: strings[shortyIdx],
          returnType: types[returnTypeIdx],
          parameterTypes: paramTypes,
        ),
      );
    }
    return protos;
  }

  List<FieldId> _parseFieldIds(
    Uint8List bytes,
    ExecutableHeader header,
    List<String> strings,
    List<String> types,
  ) {
    final c = BinaryCursor(bytes, offset: header.fieldIdsOff);
    return [
      for (var i = 0; i < header.fieldIdsSize; i++)
        FieldId(
          className: types[c.readUint16()],
          typeName: types[c.readUint16()],
          fieldName: strings[c.readUint32()],
        ),
    ];
  }

  List<MethodId> _parseMethodIds(
    Uint8List bytes,
    ExecutableHeader header,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
  ) {
    final c = BinaryCursor(bytes, offset: header.methodIdsOff);
    return [
      for (var i = 0; i < header.methodIdsSize; i++)
        MethodId(
          className: types[c.readUint16()],
          proto: protos[c.readUint16()],
          methodName: strings[c.readUint32()],
        ),
    ];
  }

  List<ClassDefinition> _parseClassDefs(
    Uint8List bytes,
    ExecutableHeader header,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    final c = BinaryCursor(bytes, offset: header.classDefsOff);
    final defs = <ClassDefinition>[];

    for (var i = 0; i < header.classDefsSize; i++) {
      final classIdx = c.readUint32();
      final accessFlags = c.readUint32();
      final superclassIdx = c.readUint32();
      final interfacesOff = c.readUint32();
      final sourceFileIdx = c.readUint32();
      final annotationsOff = c.readUint32();
      final classDataOff = c.readUint32();
      final staticValuesOff = c.readUint32();

      final interfaces = <String>[];
      if (interfacesOff != 0) {
        final ic = c.fork(interfacesOff);
        final count = ic.readUint32();
        for (var j = 0; j < count; j++) {
          interfaces.add(types[ic.readUint16()]);
        }
      }

      // Resolve all pool indices for annotations and static values at parse
      // time. DEX string tables are sorted, so a changed source path shifts
      // indices through all pools. Pre-resolving lets the differ compare
      // content without tracking index remapping.
      final parsedAnnotations = annotationsOff != 0
          ? _parseAnnotationDirectory(
              c.fork(annotationsOff),
              strings,
              types,
              protos,
              fields,
              methods,
            )
          : null;

      final parsedStaticValues = staticValuesOff != 0
          ? _parseEncodedArray(
              c.fork(staticValuesOff),
              strings,
              types,
              protos,
              fields,
              methods,
            )
          : null;

      final body = classDataOff != 0
          ? _parseClassBody(
              BinaryCursor(bytes, offset: classDataOff),
              strings,
              types,
              protos,
              fields,
              methods,
            )
          : null;

      defs.add(
        ClassDefinition(
          className: types[classIdx],
          accessFlags: accessFlags,
          superclass: superclassIdx == _noIndex ? null : types[superclassIdx],
          interfaces: interfaces,
          sourceFile: sourceFileIdx == _noIndex ? null : strings[sourceFileIdx],
          annotations: parsedAnnotations,
          staticValues: parsedStaticValues,
          body: body,
        ),
      );
    }
    return defs;
  }

  ClassBody _parseClassBody(
    BinaryCursor c,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    final staticCount = c.readUleb128();
    final instanceCount = c.readUleb128();
    final directCount = c.readUleb128();
    final virtualCount = c.readUleb128();

    FieldEntry readField(int idx) {
      final accessFlags = c.readUleb128();
      return FieldEntry(field: fields[idx], accessFlags: accessFlags);
    }

    MethodEntry readMethod(int idx) {
      final accessFlags = c.readUleb128();
      final codeOff = c.readUleb128();
      return MethodEntry(
        method: methods[idx],
        accessFlags: accessFlags,
        code: codeOff != 0
            ? _parseMethodCode(
                c.fork(codeOff),
                strings,
                types,
                protos,
                fields,
                methods,
              )
            : null,
      );
    }

    var idx = 0;
    final staticFields = <FieldEntry>[];
    for (var i = 0; i < staticCount; i++) {
      idx += c.readUleb128();
      staticFields.add(readField(idx));
    }

    idx = 0;
    final instanceFields = <FieldEntry>[];
    for (var i = 0; i < instanceCount; i++) {
      idx += c.readUleb128();
      instanceFields.add(readField(idx));
    }

    idx = 0;
    final directMethods = <MethodEntry>[];
    for (var i = 0; i < directCount; i++) {
      idx += c.readUleb128();
      directMethods.add(readMethod(idx));
    }

    idx = 0;
    final virtualMethods = <MethodEntry>[];
    for (var i = 0; i < virtualCount; i++) {
      idx += c.readUleb128();
      virtualMethods.add(readMethod(idx));
    }

    return ClassBody(
      staticFields: staticFields,
      instanceFields: instanceFields,
      directMethods: directMethods,
      virtualMethods: virtualMethods,
    );
  }

  // -- Code item ------------------------------------------------------------

  MethodCode _parseMethodCode(
    BinaryCursor c,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    final registersSize = c.readUint16();
    final insSize = c.readUint16();
    final outsSize = c.readUint16();
    final triesSize = c.readUint16();
    c.skip(4); // debug_info_off — safe to differ
    final insnsSize = c.readUint32();
    final insnsOff = c.pos;

    final buf = StringBuffer();
    _canonicalizeInstructions(
      buf,
      c.bytes,
      insnsOff,
      insnsSize,
      strings,
      types,
      protos,
      fields,
      methods,
    );

    if (triesSize > 0) {
      final pad = insnsSize % 2 != 0 ? 2 : 0;
      final triesOff = insnsOff + insnsSize * 2 + pad;
      _canonicalizeTryCatch(buf, c.bytes, triesOff, triesSize, types);
    }

    return MethodCode(
      registersSize: registersSize,
      insSize: insSize,
      outsSize: outsSize,
      canonicalBytecode: buf.toString(),
    );
  }

  void _canonicalizeInstructions(
    StringBuffer buf,
    Uint8List bytes,
    int insnsOff,
    int insnsSize,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    var pos = 0;
    while (pos < insnsSize) {
      final unit = BinaryCursor.uint16At(bytes, insnsOff + pos * 2);
      final opcode = unit & 0xFF;

      if (opcode == 0x00) {
        final payloadSize = _payloadSize(bytes, insnsOff + pos * 2);
        if (payloadSize > 0) {
          for (var i = 0; i < payloadSize; i++) {
            buf
              ..write(BinaryCursor.uint16At(bytes, insnsOff + (pos + i) * 2))
              ..write(',');
          }
          pos += payloadSize;
          continue;
        }
      }

      final size = opcodeSizes[opcode];
      final indexInfo = opcodeIndexInfo[opcode];

      for (var i = 0; i < size; i++) {
        final u = BinaryCursor.uint16At(bytes, insnsOff + (pos + i) * 2);
        final ref = indexInfo?.refAt(i);
        if (ref == null) {
          buf
            ..write(u)
            ..write(',');
        } else if (ref.is32Bit) {
          final hi =
              BinaryCursor.uint16At(bytes, insnsOff + (pos + i + 1) * 2);
          final idx = u | (hi << 16);
          buf
            ..write(
              _resolvePoolRef(idx, ref.pool, strings, types, protos, fields, methods),
            )
            ..write(',');
          i++;
        } else {
          buf
            ..write(
              _resolvePoolRef(u, ref.pool, strings, types, protos, fields, methods),
            )
            ..write(',');
        }
      }
      pos += size;
    }
  }

  String _resolvePoolRef(
    int index,
    PoolKind pool,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    switch (pool) {
      case PoolKind.string:
        return 'S:${strings[index]}';
      case PoolKind.type:
        return 'T:${types[index]}';
      case PoolKind.field:
        final f = fields[index];
        return 'F:${f.className}.${f.fieldName}:${f.typeName}';
      case PoolKind.method:
        final m = methods[index];
        final params = m.proto.parameterTypes.join(',');
        return 'M:${m.className}.${m.methodName}($params)${m.proto.returnType}';
      case PoolKind.proto:
        final p = protos[index];
        return 'P:${p.returnType}(${p.parameterTypes.join(',')})';
      case PoolKind.callSite:
        return 'CS:$index';
      case PoolKind.methodHandle:
        return 'MH:$index';
    }
  }

  void _canonicalizeTryCatch(
    StringBuffer buf,
    Uint8List bytes,
    int triesOff,
    int triesSize,
    List<String> types,
  ) {
    // try_items contain no pool indices — emit raw bytes.
    for (var i = 0; i < triesSize * 8; i++) {
      buf
        ..write(bytes[triesOff + i])
        ..write(',');
    }

    final c = BinaryCursor(bytes, offset: triesOff + triesSize * 8);
    final listSize = c.readUleb128();
    buf.write('HL:$listSize,');

    for (var i = 0; i < listSize; i++) {
      final handlerSize = c.readSleb128();
      buf.write('HS:$handlerSize,');
      for (var j = 0; j < handlerSize.abs(); j++) {
        final typeIdx = c.readUleb128();
        final addr = c.readUleb128();
        buf
          ..write('T:${types[typeIdx]},')
          ..write('A:$addr,');
      }
      if (handlerSize <= 0) {
        buf.write('CA:${c.readUleb128()},');
      }
    }
  }

  // -- Annotation parsing ---------------------------------------------------
  // All pool indices are resolved here. DEX string tables are sorted by
  // content, so any source path change reorders them, cascading through
  // type_ids, field_ids, method_ids, and proto_ids. Resolving at parse time
  // lets the differ compare annotations structurally.

  AnnotationDirectory _parseAnnotationDirectory(
    BinaryCursor c,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    final classAnnotationsOff = c.readUint32();
    final fieldsSize = c.readUint32();
    final methodsSize = c.readUint32();
    final paramsSize = c.readUint32();

    final classAnnotations = classAnnotationsOff != 0
        ? _parseAnnotationSet(
            c.fork(classAnnotationsOff),
            strings,
            types,
            protos,
            fields,
            methods,
          )
        : <Annotation>[];

    final fieldAnnotations = <String, List<Annotation>>{};
    for (var i = 0; i < fieldsSize; i++) {
      final fieldIdx = c.readUint32();
      final annotOff = c.readUint32();
      final f = fields[fieldIdx];
      fieldAnnotations['${f.className}.${f.fieldName}:${f.typeName}'] =
          _parseAnnotationSet(
            c.fork(annotOff),
            strings,
            types,
            protos,
            fields,
            methods,
          );
    }

    final methodAnnotations = <String, List<Annotation>>{};
    for (var i = 0; i < methodsSize; i++) {
      final methodIdx = c.readUint32();
      final annotOff = c.readUint32();
      final m = methods[methodIdx];
      final params = m.proto.parameterTypes.join(',');
      methodAnnotations['${m.className}.${m.methodName}($params)'] =
          _parseAnnotationSet(
            c.fork(annotOff),
            strings,
            types,
            protos,
            fields,
            methods,
          );
    }

    final paramAnnotations = <String, List<List<Annotation>>>{};
    for (var i = 0; i < paramsSize; i++) {
      final methodIdx = c.readUint32();
      final annotOff = c.readUint32();
      final m = methods[methodIdx];
      final params = m.proto.parameterTypes.join(',');
      paramAnnotations['${m.className}.${m.methodName}($params)'] =
          _parseAnnotationSetRefList(
            c.fork(annotOff),
            strings,
            types,
            protos,
            fields,
            methods,
          );
    }

    return AnnotationDirectory(
      classAnnotations: classAnnotations,
      fieldAnnotations: fieldAnnotations,
      methodAnnotations: methodAnnotations,
      parameterAnnotations: paramAnnotations,
    );
  }

  List<Annotation> _parseAnnotationSet(
    BinaryCursor c,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    final size = c.readUint32();
    return [
      for (var i = 0; i < size; i++)
        _parseAnnotationItem(
          c.fork(c.readUint32()),
          strings,
          types,
          protos,
          fields,
          methods,
        ),
    ];
  }

  List<List<Annotation>> _parseAnnotationSetRefList(
    BinaryCursor c,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    final size = c.readUint32();
    return [
      for (var i = 0; i < size; i++)
        () {
          final setOff = c.readUint32();
          return setOff == 0
              ? <Annotation>[]
              : _parseAnnotationSet(
                  c.fork(setOff),
                  strings,
                  types,
                  protos,
                  fields,
                  methods,
                );
        }(),
    ];
  }

  Annotation _parseAnnotationItem(
    BinaryCursor c,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    final visibility = c.readByte();
    return _parseEncodedAnnotation(
      c,
      strings,
      types,
      protos,
      fields,
      methods,
      visibility: visibility,
    );
  }

  Annotation _parseEncodedAnnotation(
    BinaryCursor c,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods, {
    int visibility = 0,
  }) {
    final typeIdx = c.readUleb128();
    final size = c.readUleb128();
    final elements = <String, EncodedValue>{};
    for (var i = 0; i < size; i++) {
      final nameIdx = c.readUleb128();
      elements[strings[nameIdx]] =
          _parseEncodedValue(c, strings, types, protos, fields, methods);
    }
    return Annotation(
      visibility: visibility,
      typeDescriptor: types[typeIdx],
      elements: elements,
    );
  }

  EncodedValue _parseEncodedValue(
    BinaryCursor c,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    final header = c.readByte();
    final valueType = header & 0x1F;
    final valueArg = (header >> 5) & 0x07;
    final byteCount = valueArg + 1;

    switch (valueType) {
      case 0x00: // byte
        return PrimitiveValue(typeTag: 0x00, value: c.readByte());
      case 0x02: // short
      case 0x03: // char
      case 0x04: // int
      case 0x06: // long
      case 0x10: // float
      case 0x11: // double
        return PrimitiveValue(
          typeTag: valueType,
          value: c.readSignExtended(byteCount),
        );
      case 0x15: // method_type (proto@)
        return MethodTypeValue(protos[c.readUnsigned(byteCount)]);
      case 0x16: // method_handle
        return MethodHandleValue(c.readUnsigned(byteCount));
      case 0x17: // string
        return StringValue(strings[c.readUnsigned(byteCount)]);
      case 0x18: // type
        return TypeValue(types[c.readUnsigned(byteCount)]);
      case 0x19: // field
        return FieldRefValue(fields[c.readUnsigned(byteCount)]);
      case 0x1a: // method
        return MethodRefValue(methods[c.readUnsigned(byteCount)]);
      case 0x1b: // enum (field@)
        return EnumValue(fields[c.readUnsigned(byteCount)]);
      case 0x1c: // array
        return ArrayValue(
          _parseEncodedArray(c, strings, types, protos, fields, methods),
        );
      case 0x1d: // annotation
        return AnnotationValue(
          _parseEncodedAnnotation(c, strings, types, protos, fields, methods),
        );
      case 0x1e: // null
        return const NullValue();
      case 0x1f: // boolean
        return BoolValue(value: valueArg != 0);
      default:
        // Unknown value type — store raw bytes as a primitive.
        return PrimitiveValue(
          typeTag: valueType,
          value: c.readUnsigned(byteCount),
        );
    }
  }

  List<EncodedValue> _parseEncodedArray(
    BinaryCursor c,
    List<String> strings,
    List<String> types,
    List<PrototypeId> protos,
    List<FieldId> fields,
    List<MethodId> methods,
  ) {
    final size = c.readUleb128();
    return [
      for (var i = 0; i < size; i++)
        _parseEncodedValue(c, strings, types, protos, fields, methods),
    ];
  }

  // -- Payload size ---------------------------------------------------------

  static int _payloadSize(Uint8List bytes, int off) {
    final ident = BinaryCursor.uint16At(bytes, off);
    switch (ident) {
      case 0x0100: // packed-switch-payload
        return 4 + BinaryCursor.uint16At(bytes, off + 2) * 2;
      case 0x0200: // sparse-switch-payload
        return 2 + BinaryCursor.uint16At(bytes, off + 2) * 4;
      case 0x0300: // fill-array-data-payload
        final elementWidth = BinaryCursor.uint16At(bytes, off + 2);
        final size = BinaryCursor.uint32At(bytes, off + 4);
        final totalBytes = size * elementWidth;
        return 4 + ((totalBytes + 1) ~/ 2);
      default:
        return 0;
    }
  }

  // -- MUTF-8 string reading ------------------------------------------------

  String _readMutf8String(BinaryCursor c) {
    // Skip ULEB128 size prefix (size in UTF-16 code units, not bytes).
    c.readUleb128();

    final codeUnits = <int>[];
    while (c.pos < c.bytes.length && c.bytes[c.pos] != 0) {
      final byte1 = c.readByte();
      if (byte1 & 0x80 == 0) {
        codeUnits.add(byte1);
      } else if (byte1 & 0xE0 == 0xC0) {
        final byte2 = c.readByte();
        codeUnits.add(((byte1 & 0x1F) << 6) | (byte2 & 0x3F));
      } else if (byte1 & 0xF0 == 0xE0) {
        final byte2 = c.readByte();
        final byte3 = c.readByte();
        codeUnits.add(
          ((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F),
        );
      }
    }
    return String.fromCharCodes(codeUnits);
  }
}
