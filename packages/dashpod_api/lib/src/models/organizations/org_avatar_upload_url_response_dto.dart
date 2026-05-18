import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class OrgAvatarUploadUrlResponseDto {
  OrgAvatarUploadUrlResponseDto({this.uploadUrl});

  /// Converts a `Map<String, dynamic>` to an [OrgAvatarUploadUrlResponseDto].
  factory OrgAvatarUploadUrlResponseDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'OrgAvatarUploadUrlResponseDto',
      json,
      () => OrgAvatarUploadUrlResponseDto(
        uploadUrl: json['upload_url'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static OrgAvatarUploadUrlResponseDto? maybeFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return OrgAvatarUploadUrlResponseDto.fromJson(json);
  }

  final String? uploadUrl;

  /// Converts an [OrgAvatarUploadUrlResponseDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'upload_url': uploadUrl};
  }

  @override
  int get hashCode => uploadUrl.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrgAvatarUploadUrlResponseDto &&
        uploadUrl == other.uploadUrl;
  }
}
