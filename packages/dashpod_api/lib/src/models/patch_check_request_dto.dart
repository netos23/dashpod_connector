import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/patch_check_request_dto_arch.dart';
import 'package:dashpod_api/src/models/patch_check_request_dto_platform.dart';
import 'package:meta/meta.dart';

@immutable
class PatchCheckRequestDto {
  const PatchCheckRequestDto({
    this.appId,
    this.channel,
    this.releaseVersion,
    this.platform,
    this.arch,
    this.clientId,
    this.currentPatchNumber,
  });

  /// Converts a `Map<String, dynamic>` to a [PatchCheckRequestDto].
  factory PatchCheckRequestDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PatchCheckRequestDto',
      json,
      () => PatchCheckRequestDto(
        appId: json['appId'] as String?,
        channel: json['channel'] as String?,
        releaseVersion: json['releaseVersion'] as String?,
        platform: PatchCheckRequestDtoPlatform.maybeFromJson(
          json['platform'] as String?,
        ),
        arch: PatchCheckRequestDtoArch.maybeFromJson(json['arch'] as String?),
        clientId: json['clientId'] as String?,
        currentPatchNumber: json['currentPatchNumber'] as int?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PatchCheckRequestDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PatchCheckRequestDto.fromJson(json);
  }

  final String? appId;
  final String? channel;
  final String? releaseVersion;
  final PatchCheckRequestDtoPlatform? platform;
  final PatchCheckRequestDtoArch? arch;
  final String? clientId;
  final int? currentPatchNumber;

  /// Converts a [PatchCheckRequestDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'appId': appId,
      'channel': channel,
      'releaseVersion': releaseVersion,
      'platform': platform?.toJson(),
      'arch': arch?.toJson(),
      'clientId': clientId,
      'currentPatchNumber': currentPatchNumber,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    appId,
    channel,
    releaseVersion,
    platform,
    arch,
    clientId,
    currentPatchNumber,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PatchCheckRequestDto &&
        appId == other.appId &&
        channel == other.channel &&
        releaseVersion == other.releaseVersion &&
        platform == other.platform &&
        arch == other.arch &&
        clientId == other.clientId &&
        currentPatchNumber == other.currentPatchNumber;
  }
}
