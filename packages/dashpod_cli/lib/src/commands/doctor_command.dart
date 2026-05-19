import 'dart:async';

import '../doctor/doctor.dart';
import '../doctor/validator.dart';
import '../doctor/validators/android_internet_permission_validator.dart';
import '../doctor/validators/dashpod_yaml_asset_validator.dart';
import '../env/dashpod_env.dart';
import 'dashpod_command.dart';

/// `dashpod doctor` — sanity-checks the host project.
///
/// Runs every registered [Validator]; with `--fix` it invokes each
/// fixable issue's remediation and re-validates so the user sees the
/// post-fix state. Exit code is 0 when no errors remain, 1 otherwise.
class DoctorCommand extends DashpodCommand {
  DoctorCommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    List<Validator>? validators,
  }) : _validators = validators ?? _defaultValidators(env) {
    argParser.addFlag(
      'fix',
      negatable: false,
      help: 'Apply any available auto-fixes and re-validate.',
    );
  }

  static List<Validator> _defaultValidators(DashpodEnv env) => [
        DashpodYamlAssetValidator(env: env),
        AndroidInternetPermissionValidator(env: env),
      ];

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Validate the host project; pass --fix to apply automatic remediations.';

  final List<Validator> _validators;

  @override
  Future<int> run() async {
    final applyFixes = argResults!['fix'] as bool;
    final doctor = Doctor(validators: _validators, logger: logger);
    final result = await doctor.run(applyFixes: applyFixes);

    if (isJsonMode) {
      return emitJsonSuccess(
        data: result.toJson(),
        exitCode: result.hasErrors ? 1 : 0,
      );
    }

    for (final outcome in result.outcomes) {
      if (outcome.skipped) {
        logger.detail('skip · ${outcome.validator.description} — '
            '${outcome.skipReason}');
        continue;
      }
      if (outcome.issues.isEmpty) {
        logger.info('ok   · ${outcome.validator.description}');
        continue;
      }
      for (final issue in outcome.issues) {
        final tag = switch (issue.severity) {
          ValidationIssueSeverity.error => 'err ',
          ValidationIssueSeverity.warning => 'warn',
          ValidationIssueSeverity.info => 'info',
        };
        logger.warn('$tag · ${outcome.validator.description}: '
            '${issue.message}');
        final detail = issue.displayMessage;
        if (detail != null && detail.isNotEmpty) {
          for (final line in detail.split('\n')) {
            logger.info('       $line');
          }
        }
        if (issue.hasFix && !applyFixes) {
          logger.info('       → run `dashpod doctor --fix` to apply');
        }
      }
    }

    if (result.hasErrors) {
      logger.err('doctor found unresolved errors.');
      return 1;
    }
    if (result.hasWarnings) {
      logger.warn('doctor passed with warnings.');
    } else {
      logger.info('doctor: all checks passed.');
    }
    return 0;
  }
}
