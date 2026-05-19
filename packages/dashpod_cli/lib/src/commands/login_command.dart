import 'dart:async';

import '../auth/auth_client.dart';
import '../json/json_output.dart';
import 'dashpod_command.dart';

/// `dashpod login` — runs the OAuth authorization-code loopback flow.
///
/// 1. If a credential is already stored and `--force` isn't passed, prints
///    the cached identity and exits.
/// 2. Otherwise: opens the OIDC issuer's authorization URL in the user's
///    default browser, listens on a loopback port for the redirect, and
///    exchanges the code for tokens. The URL is also printed so the user
///    can copy it manually if no browser was launched (headless box, SSH
///    session, etc.).
class LoginCommand extends DashpodCommand {
  LoginCommand({
    required super.env,
    required super.console,
    required super.json,
    required AuthClient authClient,
  }) : _auth = authClient {
    argParser.addFlag(
      'force',
      negatable: false,
      help: 'Re-authenticate even if a credential is already stored.',
    );
  }

  @override
  String get name => 'login';

  @override
  String get description =>
      'Authenticate against the Dashpod identity provider.';

  final AuthClient _auth;

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;

    if (_auth.isAuthorized && !force) {
      return _emitWhoAmI(prefix: 'Already authenticated as');
    }

    if (!env.canAcceptUserInput && !isJsonMode) {
      return _fail(
        JsonErrorCode.interactivePromptRequired,
        'Interactive login is required but no TTY is attached. '
        'Run on a workstation, or set DASHPOD_TOKEN for non-interactive use.',
      );
    }

    try {
      await _auth.authenticate(
        launcher: (url) {
          // Print the URL *before* spawning the browser so users on
          // headless machines have it even if the launcher silently no-ops.
          if (!isJsonMode) {
            console
              ..writeln('Opening browser for authentication…')
              ..writeln('If it does not open automatically, visit:')
              ..writeln('  $url');
          }
          AuthClient.defaultLauncher(url);
        },
      );
    } catch (e) {
      return _fail(JsonErrorCode.fetchFailed, 'Authentication failed: $e');
    }

    return _emitWhoAmI(prefix: 'Authenticated as');
  }

  Future<int> _emitWhoAmI({required String prefix}) async {
    Map<String, dynamic>? info;
    try {
      final user = await _auth.getUserInfo();
      info = user?.toJson();
    } catch (_) {
      // Userinfo is best-effort — login itself succeeded.
    }
    final email = info?['email'] as String? ??
        info?['preferred_username'] as String?;

    if (isJsonMode) {
      final data = <String, Object?>{'authenticated': true};
      if (email != null) data['email'] = email;
      if (info != null) data['user_info'] = info;
      return emitJsonSuccess(data: data);
    }

    if (email != null) {
      console.writeln('$prefix $email.');
    } else {
      console.writeln('$prefix unknown user (no userinfo endpoint).');
    }
    return 0;
  }

  int _fail(JsonErrorCode code, String message) {
    if (isJsonMode) return emitJsonError(code: code, message: message);
    console.errorln(message);
    return 1;
  }
}
