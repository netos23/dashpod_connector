import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class PatchPayloadDto {
  PatchPayloadDto({
    this.number,
    this.downloadUrl,
    this.hash,
    this.hashSignature,
  });

  /// Converts a `Map<String, dynamic>` to a [PatchPayloadDto].
  factory PatchPayloadDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PatchPayloadDto',
      json,
      () => PatchPayloadDto(
        number: (json['number'] as int?),
        downloadUrl: json['downloadUrl'] as String?,
        hash: json['hash'] as String?,
        hashSignature: json['hashSignature'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PatchPayloadDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PatchPayloadDto.fromJson(json);
  }

  final int? number;
  final String? downloadUrl;
  final String? hash;
  final String? hashSignature;

  /// Converts a [PatchPayloadDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'downloadUrl': downloadUrl,
      'hash': hash,
      'hashSignature': hashSignature,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([number, downloadUrl, hash, hashSignature]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PatchPayloadDto &&
        number == other.number &&
        downloadUrl == other.downloadUrl &&
        hash == other.hash &&
        hashSignature == other.hashSignature;
  }
}
