import 'package:dashpod_api/model_helpers.dart';
import 'package:meta/meta.dart';

@immutable
class UserDto {
  UserDto({
    this.id,
    this.email,
    this.jwtIssuer,
    this.hasActiveSubscription,
    this.displayName,
    this.stripeCustomerId,
    this.patchOverageLimit,
  });

  /// Converts a `Map<String, dynamic>` to a [UserDto].
  factory UserDto.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'UserDto',
      json,
      () => UserDto(
        id: (json['id'] as int?),
        email: json['email'] as String?,
        jwtIssuer: json['jwtIssuer'] as String?,
        hasActiveSubscription: json['hasActiveSubscription'] as bool?,
        displayName: json['displayName'] as String?,
        stripeCustomerId: json['stripeCustomerId'] as String?,
        patchOverageLimit: (json['patchOverageLimit'] as int?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static UserDto? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return UserDto.fromJson(json);
  }

  final int? id;
  final String? email;
  final String? jwtIssuer;
  final bool? hasActiveSubscription;
  final String? displayName;
  final String? stripeCustomerId;
  final int? patchOverageLimit;

  /// Converts a [UserDto] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'jwtIssuer': jwtIssuer,
      'hasActiveSubscription': hasActiveSubscription,
      'displayName': displayName,
      'stripeCustomerId': stripeCustomerId,
      'patchOverageLimit': patchOverageLimit,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    email,
    jwtIssuer,
    hasActiveSubscription,
    displayName,
    stripeCustomerId,
    patchOverageLimit,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserDto &&
        id == other.id &&
        email == other.email &&
        jwtIssuer == other.jwtIssuer &&
        hasActiveSubscription == other.hasActiveSubscription &&
        displayName == other.displayName &&
        stripeCustomerId == other.stripeCustomerId &&
        patchOverageLimit == other.patchOverageLimit;
  }
}
