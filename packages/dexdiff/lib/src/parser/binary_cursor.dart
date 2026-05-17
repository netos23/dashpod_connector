import 'dart:typed_data';

/// A cursor-based reader for sequential binary parsing of little-endian data.
///
/// Maintains a mutable position into an immutable [Uint8List]. Use [fork] to
/// create a sibling cursor at a different offset without advancing this one.
final class BinaryCursor {
  BinaryCursor(this.bytes, {int offset = 0}) : _pos = offset;

  final Uint8List bytes;
  int _pos;

  int get pos => _pos;

  /// Creates a new cursor at [offset] sharing the same [bytes].
  BinaryCursor fork(int offset) => BinaryCursor(bytes, offset: offset);

  void skip(int count) => _pos += count;

  int readByte() => bytes[_pos++];

  int readUint16() {
    final v = bytes[_pos] | (bytes[_pos + 1] << 8);
    _pos += 2;
    return v;
  }

  int readUint32() {
    final v =
        bytes[_pos] |
        (bytes[_pos + 1] << 8) |
        (bytes[_pos + 2] << 16) |
        (bytes[_pos + 3] << 24);
    _pos += 4;
    return v;
  }

  int readUleb128() {
    var result = 0;
    var shift = 0;
    while (true) {
      final byte = bytes[_pos++];
      result |= (byte & 0x7F) << shift;
      if (byte & 0x80 == 0) break;
      shift += 7;
    }
    return result;
  }

  int readSleb128() {
    var result = 0;
    var shift = 0;
    int byte;
    do {
      byte = bytes[_pos++];
      result |= (byte & 0x7F) << shift;
      shift += 7;
    } while (byte & 0x80 != 0);
    if (shift < 64 && (byte & 0x40) != 0) {
      result |= -(1 << shift);
    }
    return result;
  }

  /// Reads [byteCount] bytes as an unsigned little-endian integer.
  int readUnsigned(int byteCount) {
    var value = 0;
    for (var i = 0; i < byteCount; i++) {
      value |= bytes[_pos++] << (i * 8);
    }
    return value;
  }

  /// Reads [byteCount] bytes as a sign-extended little-endian integer.
  int readSignExtended(int byteCount) {
    var value = 0;
    for (var i = 0; i < byteCount; i++) {
      value |= bytes[_pos++] << (i * 8);
    }
    final shift = byteCount * 8;
    if (shift < 64 && (value & (1 << (shift - 1))) != 0) {
      value |= -(1 << shift);
    }
    return value;
  }

  // -- Static helpers used by the parser where a cursor isn't held ----------

  static int uint16At(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int uint32At(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}
