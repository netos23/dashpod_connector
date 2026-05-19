import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'api/api_client.dart';
import 'auth/auth_client.dart';
import 'auth/auth_config.dart';
import 'auth/credential_storage.dart';
import 'commands/init_command.dart';
import 'commands/login_command.dart';
import 'commands/logout_command.dart';
import 'env/dashpod_env.dart';
import 'io/console.dart';
import 'json/json_output.dart';

const cliVersion = '0.0.1';

/// Top-level command runner for `dashpod`.
///
/// Responsibilities:
///   * declares the global flags `--version`, `--json`, `--verbose`
///   * pre-scans argv for `--json` so that even usage / parse failures can
///     emit the JSON envelope on stdout
///   * constructs shared services (env, console, JSON sink, auth client,
///     API client factory) and passes them to every registered command.
///     There is no DI container — constructor injection is enough at this
///     scale.
class DashpodCliCommandRunner extends CommandRunner<int> {
  DashpodCliCommandRunner({
    DashpodEnv? env,
    ConsoleIo? console,
    DashpodApiClientFactory? apiClientFactory,
    AuthClient? authClient,
    IOSink? stdoutSink,
    IOSink? stderrSink,
  })  : _env = env ?? DashpodEnv.fromPlatform(),
        _stdout = stdoutSink ?? stdout,
        _stderr = stderrSink ?? stderr,
        super(
          'dashpod',
          'Developer CLI for the Dashpod code-push system.',
        ) {
    final resolvedConsole = console ?? ConsoleIo.fromStdio();
    final resolvedAuth = authClient ?? _buildAuthClient(_env);
    final resolvedFactory = apiClientFactory ??
        (DashpodEnv e) =>
            DashpodApiClient.build(env: e, authClient: resolvedAuth);

    argParser
      ..addFlag(
        'version',
        negatable: false,
        help: 'Print the CLI version.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Show additional output (timings, request URLs).',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Emit a single JSON envelope on stdout; suppress ANSI output.',
      );

    addCommand(
      InitCommand(
        env: _env,
        console: resolvedConsole,
        apiClientFactory: resolvedFactory,
        json: _jsonSink,
      ),
    );
    addCommand(
      LoginCommand(
        env: _env,
        console: resolvedConsole,
        json: _jsonSink,
        authClient: resolvedAuth,
      ),
    );
    addCommand(
      LogoutCommand(
        env: _env,
        console: resolvedConsole,
        json: _jsonSink,
        authClient: resolvedAuth,
      ),
    );
  }

  static AuthClient _buildAuthClient(DashpodEnv env) {
    return AuthClient.load(
      config: AuthConfig.fromEnvironment(env.environment),
      storage: CredentialStorage.inDirectory(env.configDirectory),
    );
  }

  final DashpodEnv _env;
  final IOSink _stdout;
  final IOSink _stderr;
  bool _jsonMode = false;

  JsonOutputSink get _jsonSink => JsonOutputSink(
        sink: _stdout,
        enabled: () => _jsonMode,
      );

  bool _detectJsonMode(List<String> args) => args.contains('--json');

  @override
  Future<int?> run(Iterable<String> args) async {
    final argList = args.toList(growable: false);
    _jsonMode = _detectJsonMode(argList);
    try {
      return await super.run(argList);
    } on FormatException catch (e) {
      return _emitUsageError(e.message);
    } on UsageException catch (e) {
      return _emitUsageError(e.message, usage: e.usage);
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] as bool) {
      if (_jsonMode) {
        _jsonSink.success(
          command: 'dashpod',
          data: {'version': cliVersion},
        );
      } else {
        _stdout.writeln('dashpod $cliVersion');
      }
      return 0;
    }
    return super.runCommand(topLevelResults);
  }

  int _emitUsageError(String message, {String? usage}) {
    if (_jsonMode) {
      _jsonSink.error(
        command: 'dashpod',
        code: JsonErrorCode.usageError,
        message: message,
      );
    } else {
      _stderr.writeln(message);
      if (usage != null) {
        _stderr
          ..writeln()
          ..writeln(usage);
      }
    }
    return 64; // EX_USAGE
  }
}
