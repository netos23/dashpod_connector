import 'package:dashpod_api/model_helpers.dart';
import 'package:dashpod_api/src/models/patch_artifact_dto.dart';
import 'package:meta/meta.dart';

@immutable
class ReleasePatchDto {
  ReleasePatchDto({
    this.id,
    this.number,
    this.artifacts,
    this.notes,
    this.channel,
    this.rolledBack,
  });

  /// Converts a `Map<String, dynamic>` to a [ReleasePatchDto].
  factory ReleasePatchDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ReleasePatchDto',
      json,
      () => ReleasePatchDto(
        id: (json['id'] as int?),
        number: (json['number'] as int?),
        artifacts: (json['artifacts'] as List?)
            ?.map<PatchArtifactDto>(
              (e) => PatchArtifactDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        notes: json['notes'] as String?,
        channel: json['channel'] as String?,
        rolledBack: json['rolledBack'] as bool?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ReleasePatchDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ReleasePatchDto.fromJson(json);
  }

  final int? id;
  final int? number;
  final List<PatchArtifactDto>? artifacts;
  final String? notes;
  final String? channel;
  final bool? rolledBack;

  /// Converts a [ReleasePatchDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'artifacts': artifacts?.map((e) => e.toJson()).toList(),
      'notes': notes,
      'channel': channel,
      'rolledBack': rolledBack,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    number,
    listHash(artifacts),
    notes,
    channel,
    rolledBack,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReleasePatchDto &&
        id == other.id &&
        number == other.number &&
        listsEqual(artifacts, other.artifacts) &&
        notes == other.notes &&
        channel == other.channel &&
        rolledBack == other.rolledBack;
  }
}
