import 'dart:async';

import '../auth/auth_client.dart';
import 'dashpod_command.dart';

/// `dashpod logout` — discards the stored credential.
///
/// Local-only: does not perform an RP-initiated logout against the
/// identity provider (no `end_session_endpoint` call). The refresh token
/// remains valid on the server until it expires; if you need full
/// invalidation you must revoke it server-side.
class LogoutCommand extends DashpodCommand {
  LogoutCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required AuthClient authClient,
  }) : _auth = authClient;

  @override
  String get name => 'logout';

  @override
  String get description =>
      'Discard the stored credential. Does not revoke server-side.';

  final AuthClient _auth;

  @override
  Future<int> run() async {
    final wasAuthorized = _auth.isAuthorized;
    await _auth.logout();
    if (isJsonMode) {
      return emitJsonSuccess(data: {'was_authenticated': wasAuthorized});
    }
    logger.info(
      wasAuthorized
          ? 'Logged out. Local credential discarded.'
          : 'No stored credential found.',
    );
    return 0;
  }
}
