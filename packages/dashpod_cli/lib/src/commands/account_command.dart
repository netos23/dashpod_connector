import 'dart:async';

import '../api/api_client.dart';
import '../auth/auth_client.dart';
import '../json/json_output.dart';
import 'dashpod_command.dart';

/// `dashpod account` — parent for read-only identity commands.
///
/// Pure dispatcher; the real work lives in the subcommands. Each
/// subcommand needs the same set of services (env, console, auth, API),
/// so they're constructed here and passed down via constructor injection.
class AccountCommand extends DashpodCommand {
  AccountCommand({
    required super.env,
    required super.console,
    required super.logger,
    required JsonOutputSink json,
    required AuthClient authClient,
    required DashpodApiClientFactory apiClientFactory,
  }) : super(json: json) {
    addSubcommand(_WhoAmICommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      authClient: authClient,
      apiClientFactory: apiClientFactory,
    ));
    addSubcommand(_OrgsCommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      authClient: authClient,
      apiClientFactory: apiClientFactory,
    ));
    addSubcommand(_AppsCommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      authClient: authClient,
      apiClientFactory: apiClientFactory,
    ));
  }

  @override
  String get name => 'account';

  @override
  String get description =>
      'Inspect the currently-authenticated identity and its resources.';
}

/// Shared base for the three subcommands. Each is one API call plus a
/// trivial formatter — splitting them into separate files would be
/// premature.
abstract class _AccountSubcommand extends DashpodCommand {
  _AccountSubcommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required AuthClient authClient,
    required DashpodApiClientFactory apiClientFactory,
  })  : _auth = authClient,
        _apiClientFactory = apiClientFactory;

  final AuthClient _auth;
  final DashpodApiClientFactory _apiClientFactory;

  DashpodApiClient buildApi() => _apiClientFactory(env);

  /// Short-circuits with a uniform "not logged in" envelope.
  int? requireAuth() {
    final hasStaticToken = (env.sessionToken ?? '').isNotEmpty;
    if (_auth.isAuthorized || hasStaticToken) return null;
    return _fail(
      JsonErrorCode.softwareError,
      'Not authenticated. Run `dashpod login` first.',
    );
  }

  int _fail(JsonErrorCode code, String message) {
    if (isJsonMode) return emitJsonError(code: code, message: message);
    logger.err(message);
    return 1;
  }

  int reportFetchFailure(Object error) =>
      _fail(JsonErrorCode.fetchFailed, '$runtimeType: $error');
}

class _WhoAmICommand extends _AccountSubcommand {
  _WhoAmICommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required super.authClient,
    required super.apiClientFactory,
  });

  @override
  String get name => 'whoami';

  @override
  String get description => 'Print the currently-authenticated user.';

  @override
  Future<int> run() async {
    final guard = requireAuth();
    if (guard != null) return guard;

    try {
      final user = await buildApi().users.listMe();
      if (isJsonMode) {
        return emitJsonSuccess(data: user.toJson());
      }
      logger.info('id           : ${user.id ?? "(unknown)"}');
      logger.info('email        : ${user.email ?? "(unknown)"}');
      if (user.displayName != null) {
        logger.info('display name : ${user.displayName}');
      }
      if (user.jwtIssuer != null) {
        logger.info('jwt issuer   : ${user.jwtIssuer}');
      }
      return 0;
    } catch (e) {
      return reportFetchFailure(e);
    }
  }
}

class _OrgsCommand extends _AccountSubcommand {
  _OrgsCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required super.authClient,
    required super.apiClientFactory,
  });

  @override
  String get name => 'orgs';

  @override
  String get description =>
      'List organisations the current user belongs to.';

  @override
  Future<int> run() async {
    final guard = requireAuth();
    if (guard != null) return guard;

    try {
      final response = await buildApi().organizations.listOrganizations();
      final memberships = response.organizations ?? const [];

      if (isJsonMode) {
        return emitJsonSuccess(data: {
          'organizations': memberships
              .map((m) => {
                    ...?m.organization?.toJson(),
                    if (m.role != null) 'role': m.role!.toJson(),
                  })
              .toList(),
        });
      }

      if (memberships.isEmpty) {
        logger.info('No organisations.');
        return 0;
      }
      for (final m in memberships) {
        final org = m.organization;
        final role = m.role?.toJson() ?? '(unknown role)';
        logger.info(
          '#${org?.id ?? "?"}  ${org?.name ?? "(unnamed)"}  [$role]',
        );
      }
      return 0;
    } catch (e) {
      return reportFetchFailure(e);
    }
  }
}

class _AppsCommand extends _AccountSubcommand {
  _AppsCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required super.authClient,
    required super.apiClientFactory,
  });

  @override
  String get name => 'apps';

  @override
  String get description => 'List apps visible to the current user.';

  @override
  Future<int> run() async {
    final guard = requireAuth();
    if (guard != null) return guard;

    try {
      final response = await buildApi().apps.listApps();
      final apps = response.apps ?? const [];

      if (isJsonMode) {
        return emitJsonSuccess(data: {
          'apps': apps.map((a) => a.toJson()).toList(),
        });
      }

      if (apps.isEmpty) {
        logger.info('No apps.');
        return 0;
      }
      for (final a in apps) {
        final pieces = <String>[
          a.appId ?? '(no id)',
          a.displayName ?? '(unnamed)',
        ];
        if (a.latestReleaseVersion != null) {
          pieces.add('release ${a.latestReleaseVersion}');
        }
        if (a.latestPatchNumber != null) {
          pieces.add('patch ${a.latestPatchNumber}');
        }
        logger.info(pieces.join('  ·  '));
      }
      return 0;
    } catch (e) {
      return reportFetchFailure(e);
    }
  }
}

