import 'dart:async';
import 'dart:io';

import 'package:openid_client/openid_client.dart' as oidc;
import 'package:openid_client/openid_client_io.dart' as oidc_io;

import 'auth_config.dart';
import 'credential_storage.dart';

/// Signature of the callback that opens a URL in the user's browser.
typedef UrlLauncher = void Function(String url);

/// Owns the OAuth/OIDC lifecycle for the CLI.
///
/// Construction is synchronous: existing credentials (if any) are loaded
/// from [storage] eagerly so commands can decide whether to prompt for
/// login. The expensive step — discovering the OIDC issuer — is deferred
/// until [authenticate] is actually called.
class AuthClient {
  AuthClient._({
    required this.config,
    required CredentialStorage storage,
    oidc.Credential? initial,
  })  : _storage = storage,
        _credential = initial;

  /// Builds an AuthClient and eagerly loads a stored credential if one
  /// exists. Returns a client with `isAuthorized == false` when the file
  /// is missing or unreadable.
  factory AuthClient.load({
    required AuthConfig config,
    required CredentialStorage storage,
  }) {
    oidc.Credential? credential;
    try {
      credential = storage.load();
    } catch (_) {
      credential = null;
    }
    return AuthClient._(
      config: config,
      storage: storage,
      initial: credential,
    );
  }

  final AuthConfig config;
  final CredentialStorage _storage;
  oidc.Credential? _credential;

  bool get isAuthorized => _credential != null;

  /// Best-effort access token. Does *not* refresh; the [authInterceptor]
  /// is responsible for catching 401/403 and calling [refresh].
  String? get accessToken => _credential?.response?['access_token'] as String?;

  oidc.Credential? get credential => _credential;

  /// Runs the authorization-code flow against the configured issuer.
  ///
  /// Discovers the issuer, then spins up a loopback HTTP server on the
  /// configured port, opens the auth URL via [launcher] (defaults to the
  /// OS-native browser opener), waits for the redirect, and exchanges the
  /// code for tokens. The resulting credential is persisted before being
  /// returned.
  Future<oidc.Credential> authenticate({UrlLauncher? launcher}) async {
    final issuer = await oidc.Issuer.discover(config.issuerUri);
    final client = oidc.Client(
      issuer,
      config.clientId,
      clientSecret: config.clientSecret,
    );
    final authenticator = oidc_io.Authenticator(
      client,
      port: config.loopbackPort,
      scopes: config.scopes,
      urlLancher: launcher ?? defaultLauncher,
      redirectMessage: config.successMessage,
    );
    final credential = await authenticator.authorize();
    _credential = credential;
    _storage.save(credential);
    return credential;
  }

  /// Forces a token refresh. Persists the new tokens. Calls [logout] and
  /// rethrows if the refresh itself failed (typical reason: refresh token
  /// expired or revoked — the user must re-authenticate).
  Future<oidc.TokenResponse> refresh() async {
    final credential = _credential;
    if (credential == null) {
      throw StateError('Cannot refresh: no stored credential. Run `dashpod login`.');
    }
    try {
      final tokens = await credential.getTokenResponse(true);
      _storage.save(credential);
      return tokens;
    } catch (_) {
      await logout();
      rethrow;
    }
  }

  Future<oidc.UserInfo?> getUserInfo() async {
    final credential = _credential;
    if (credential == null) return null;
    return credential.getUserInfo();
  }

  Future<void> logout() async {
    _credential = null;
    _storage.delete();
  }

  /// Best-effort OS-native browser opener. Mirrors the same dispatch
  /// `openid_client_io` does internally but with two adjustments:
  ///  * Windows uses `cmd /c start "" <url>` so URLs containing `&` aren't
  ///    interpreted as `start` arguments.
  ///  * Linux prefers `xdg-open` (more widely installed than
  ///    `x-www-browser`).
  static void defaultLauncher(String url) {
    if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', url]);
    } else {
      Process.run('xdg-open', [url]);
    }
  }
}
