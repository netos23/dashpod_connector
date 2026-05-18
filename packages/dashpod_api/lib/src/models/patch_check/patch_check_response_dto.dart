import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/patches/patch_payload_dto.dart';
import 'package:meta/meta.dart';

@immutable
class PatchCheckResponseDto {
  PatchCheckResponseDto({
    this.patchAvailable,
    this.patch,
    this.rolledBackPatchNumbers,
  });

  /// Converts a `Map<String, dynamic>` to a [PatchCheckResponseDto].
  factory PatchCheckResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PatchCheckResponseDto',
      json,
      () => PatchCheckResponseDto(
        patchAvailable: json['patch_available'] as bool?,
        patch: PatchPayloadDto.maybeFromJson(
          json['patch'] as Map<String, dynamic>?,
        ),
        rolledBackPatchNumbers: (json['rolled_back_patch_numbers'] as List?)
            ?.cast<int>(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PatchCheckResponseDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PatchCheckResponseDto.fromJson(json);
  }

  final bool? patchAvailable;
  final PatchPayloadDto? patch;
  final List<int>? rolledBackPatchNumbers;

  /// Converts a [PatchCheckResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'patch_available': patchAvailable,
      'patch': patch?.toJson(),
      'rolled_back_patch_numbers': rolledBackPatchNumbers,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([patchAvailable, patch, listHash(rolledBackPatchNumbers)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PatchCheckResponseDto &&
        patchAvailable == other.patchAvailable &&
        patch == other.patch &&
        listsEqual(rolledBackPatchNumbers, other.rolledBackPatchNumbers);
  }
}
