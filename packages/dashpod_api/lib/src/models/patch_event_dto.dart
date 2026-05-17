import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/patch_event_dto_type.dart';
import 'package:meta/meta.dart';

@immutable
class PatchEventDto {
  PatchEventDto({
    this.appId,
    this.arch,
    this.clientId,
    this.type,
    this.patchNumber,
    this.platform,
    this.releaseVersion,
    this.timestamp,
    this.message,
  });

  /// Converts a `Map<String, dynamic>` to a [PatchEventDto].
  factory PatchEventDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PatchEventDto',
      json,
      () => PatchEventDto(
        appId: json['appId'] as String?,
        arch: json['arch'] as String?,
        clientId: json['clientId'] as String?,
        type: PatchEventDtoType.maybeFromJson(json['type'] as String?),
        patchNumber: (json['patchNumber'] as int?),
        platform: json['platform'] as String?,
        releaseVersion: json['releaseVersion'] as String?,
        timestamp: (json['timestamp'] as int?),
        message: json['message'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PatchEventDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PatchEventDto.fromJson(json);
  }

  final String? appId;
  final String? arch;
  final String? clientId;
  final PatchEventDtoType? type;
  final int? patchNumber;
  final String? platform;
  final String? releaseVersion;
  final int? timestamp;
  final String? message;

  /// Converts a [PatchEventDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'appId': appId,
      'arch': arch,
      'clientId': clientId,
      'type': type?.toJson(),
      'patchNumber': patchNumber,
      'platform': platform,
      'releaseVersion': releaseVersion,
      'timestamp': timestamp,
      'message': message,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    appId,
    arch,
    clientId,
    type,
    patchNumber,
    platform,
    releaseVersion,
    timestamp,
    message,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PatchEventDto &&
        appId == other.appId &&
        arch == other.arch &&
        clientId == other.clientId &&
        type == other.type &&
        patchNumber == other.patchNumber &&
        platform == other.platform &&
        releaseVersion == other.releaseVersion &&
        timestamp == other.timestamp &&
        message == other.message;
  }
}
