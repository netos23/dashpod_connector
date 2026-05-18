import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class PromotePatchRequestDto {
  PromotePatchRequestDto({this.patchId, this.channelId});

  /// Converts a `Map<String, dynamic>` to a [PromotePatchRequestDto].
  factory PromotePatchRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PromotePatchRequestDto',
      json,
      () => PromotePatchRequestDto(
        patchId: (json['patch_id'] as int?),
        channelId: (json['channel_id'] as int?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PromotePatchRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PromotePatchRequestDto.fromJson(json);
  }

  final int? patchId;
  final int? channelId;

  /// Converts a [PromotePatchRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'patch_id': patchId, 'channel_id': channelId};
  }

  @override
  int get hashCode => Object.hashAll([patchId, channelId]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PromotePatchRequestDto &&
        patchId == other.patchId &&
        channelId == other.channelId;
  }
}
