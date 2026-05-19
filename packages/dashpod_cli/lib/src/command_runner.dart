import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'api/api_client.dart';
import 'auth/auth_client.dart';
import 'auth/auth_config.dart';
import 'auth/credential_storage.dart';
import 'cache/cache.dart';
import 'commands/account_command.dart';
import 'commands/cache_command.dart';
import 'commands/doctor_command.dart';
import 'commands/init_command.dart';
import 'commands/login_command.dart';
import 'commands/logout_command.dart';
import 'commands/release/release_command.dart';
import 'env/dashpod_env.dart';
import 'io/console.dart';
import 'json/json_output.dart';
import 'logger/logger.dart';
import 'process/dashpod_process.dart';

const cliVersion = '0.0.1';

/// Top-level command runner for `dashpod`.
///
/// Responsibilities:
///   * declares the global flags `--version`, `--json`, `--verbose`
///   * pre-scans argv for `--json` and `--verbose` so usage / parse
///     failures honour the same modes as a successful command run
///   * constructs shared services (env, console, logger, JSON sink, auth
///     client, process wrapper, cache, API client factory) and passes
///     them to every registered command. There is no DI container —
///     constructor injection is enough at this scale.
class DashpodCliCommandRunner extends CommandRunner<int> {
  DashpodCliCommandRunner({
    DashpodEnv? env,
    ConsoleIo? console,
    Logger? logger,
    DashpodProcess? process,
    Cache? cache,
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
    final resolvedLogger = logger ??
        Logger(
          stdoutSink: _stdout,
          stderrSink: _stderr,
          logsDirectory: _env.logsDirectory,
          isVerbose: () => _verbose,
          isJsonMode: () => _jsonMode,
        );
    _logger = resolvedLogger;

    final resolvedAuth = authClient ?? _buildAuthClient(_env);
    final resolvedProcess =
        process ?? DashpodProcess(env: _env, logger: resolvedLogger);
    final resolvedCache =
        cache ?? Cache(env: _env, logger: resolvedLogger);
    final resolvedFactory = apiClientFactory ??
        (DashpodEnv e) =>
            DashpodApiClient.build(env: e, authClient: resolvedAuth);

    _process = resolvedProcess;
    _cache = resolvedCache;

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

    addCommand(InitCommand(
      env: _env,
      console: resolvedConsole,
      logger: resolvedLogger,
      apiClientFactory: resolvedFactory,
      process: resolvedProcess,
      json: _jsonSink,
    ));
    addCommand(DoctorCommand(
      env: _env,
      console: resolvedConsole,
      logger: resolvedLogger,
      json: _jsonSink,
    ));
    addCommand(LoginCommand(
      env: _env,
      console: resolvedConsole,
      logger: resolvedLogger,
      json: _jsonSink,
      authClient: resolvedAuth,
    ));
    addCommand(LogoutCommand(
      env: _env,
      console: resolvedConsole,
      logger: resolvedLogger,
      json: _jsonSink,
      authClient: resolvedAuth,
    ));
    addCommand(AccountCommand(
      env: _env,
      console: resolvedConsole,
      logger: resolvedLogger,
      json: _jsonSink,
      authClient: resolvedAuth,
      apiClientFactory: resolvedFactory,
    ));
    addCommand(CacheCommand(
      env: _env,
      console: resolvedConsole,
      logger: resolvedLogger,
      json: _jsonSink,
      cache: resolvedCache,
    ));
    addCommand(ReleaseCommand(
      env: _env,
      console: resolvedConsole,
      logger: resolvedLogger,
      json: _jsonSink,
      apiClientFactory: resolvedFactory,
      process: resolvedProcess,
    ));
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
  late final Logger _logger;
  late final DashpodProcess _process;
  late final Cache _cache;
  bool _jsonMode = false;
  bool _verbose = false;

  /// Exposed for tests / future commands that need to hand a shared
  /// process wrapper to a service object.
  DashpodProcess get process => _process;
  Cache get cache => _cache;
  Logger get logger => _logger;

  JsonOutputSink get _jsonSink => JsonOutputSink(
        sink: _stdout,
        enabled: () => _jsonMode,
      );

  bool _hasFlag(List<String> args, String flag, [String? short]) {
    for (final a in args) {
      if (a == flag) return true;
      if (short != null && a == short) return true;
    }
    return false;
  }

  @override
  Future<int?> run(Iterable<String> args) async {
    final argList = args.toList(growable: false);
    _jsonMode = _hasFlag(argList, '--json');
    _verbose = _hasFlag(argList, '--verbose', '-v');
    try {
      return await super.run(argList);
    } on FormatException catch (e) {
      return _emitUsageError(e.message);
    } on UsageException catch (e) {
      return _emitUsageError(e.message, usage: e.usage);
    } finally {
      await _logger.close();
      _cache.close();
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
