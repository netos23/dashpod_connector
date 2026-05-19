import 'package:meta/meta.dart';

/// Static OIDC client configuration.
///
/// Defaults target the Keycloak realm at `dashpod.fbtw.pro`. Every field is
/// overridable via an environment variable so we don't have to ship a build
/// per environment.
///
/// The "client secret" of a public CLI client is not actually a secret
/// (anyone with the binary can extract it), but Keycloak still expects it
/// for confidential-client configs. Treat it as a client identifier with a
/// second factor, not a security boundary.
@immutable
class AuthConfig {
  const AuthConfig({
    required this.issuerUri,
    required this.clientId,
    this.clientSecret,
    this.scopes = const ['openid', 'profile', 'email', 'offline_access'],
    this.loopbackPort = 0,
    this.successMessage = 'Login complete. You can close this tab.',
  });

  /// OpenID Connect issuer (the realm root, *not* the well-known URL —
  /// `openid_client` appends `.well-known/openid-configuration` itself).
  final Uri issuerUri;

  /// Keycloak client id.
  final String clientId;

  /// Optional client secret. Required for confidential clients only.
  final String? clientSecret;

  /// OAuth scopes requested. `offline_access` is required for a refresh
  /// token to be returned.
  final List<String> scopes;

  /// Loopback port for the redirect server. `0` lets the OS pick a free
  /// port — preferred unless the OIDC client is locked down to specific
  /// redirect URIs (in which case set this and whitelist
  /// `http://localhost:<port>/` on the server side).
  final int loopbackPort;

  /// Message shown in the browser tab after the redirect lands.
  final String successMessage;

  static const _defaultIssuer = 'https://dashpod.fbtw.pro/auth/realms/dashpod/';
  static const _defaultClientId = 'dashpod';
  static const _defaultClientSecret = 'H6MSTP9lEgsoeYNN8ehsmw0DyIVlqCgD';

  /// Builds a config from process environment, falling back to defaults
  /// scoped to the dashpod Keycloak realm.
  factory AuthConfig.fromEnvironment(Map<String, String> env) {
    final port = int.tryParse(env['DASHPOD_AUTH_PORT'] ?? '') ?? 0;
    final scopes = env['DASHPOD_AUTH_SCOPES']?.split(RegExp(r'[\s,]+'));
    return AuthConfig(
      issuerUri: Uri.parse(env['DASHPOD_AUTH_URL'] ?? _defaultIssuer),
      clientId: env['DASHPOD_CLIENT_ID'] ?? _defaultClientId,
      clientSecret: env['DASHPOD_CLIENT_SECRET'] ?? _defaultClientSecret,
      scopes: (scopes == null || scopes.isEmpty)
          ? const ['openid', 'profile', 'email', 'offline_access']
          : scopes,
      loopbackPort: port,
    );
  }
}
