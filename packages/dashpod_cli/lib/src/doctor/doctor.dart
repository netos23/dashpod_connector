import 'dart:async';

import '../logger/logger.dart';
import 'validator.dart';

/// Per-validator outcome aggregated by the [Doctor] runner.
class ValidatorOutcome {
  ValidatorOutcome({
    required this.validator,
    required this.issues,
    this.skipped = false,
    this.skipReason,
  });

  final Validator validator;
  final List<ValidationIssue> issues;
  final bool skipped;
  final String? skipReason;

  bool get hasErrors =>
      issues.any((i) => i.severity == ValidationIssueSeverity.error);
  bool get hasWarnings =>
      issues.any((i) => i.severity == ValidationIssueSeverity.warning);

  Map<String, Object?> toJson() => {
        'validator': validator.description,
        'skipped': skipped,
        if (skipReason != null) 'skip_reason': skipReason,
        'issues': issues.map((i) => i.toJson()).toList(),
      };
}

/// Aggregate result of a [Doctor.run] call.
class DoctorResult {
  DoctorResult({required this.outcomes});

  final List<ValidatorOutcome> outcomes;

  bool get hasErrors => outcomes.any((o) => o.hasErrors);
  bool get hasWarnings => outcomes.any((o) => o.hasWarnings);

  Map<String, Object?> toJson() => {
        'has_errors': hasErrors,
        'has_warnings': hasWarnings,
        'outcomes': outcomes.map((o) => o.toJson()).toList(),
      };
}

/// Runs a fixed list of [Validator]s and reports the aggregate result.
///
/// When `applyFixes` is true, every fixable issue's `fix` callback is
/// invoked once, then the validator is re-run so the user sees the
/// post-fix state (and any issues that are still present).
class Doctor {
  Doctor({required this.validators, required this.logger});

  final List<Validator> validators;
  final Logger logger;

  Future<DoctorResult> run({bool applyFixes = false}) async {
    final outcomes = <ValidatorOutcome>[];
    for (final v in validators) {
      logger.detail('doctor: ${v.description}');
      if (!v.canRunInCurrentContext()) {
        outcomes.add(ValidatorOutcome(
          validator: v,
          issues: const [],
          skipped: true,
          skipReason: v.incorrectContextMessage,
        ));
        continue;
      }
      var issues = await v.validate();
      if (applyFixes) {
        final fixable = issues.where((i) => i.hasFix).toList();
        if (fixable.isNotEmpty) {
          for (final issue in fixable) {
            logger.detail('doctor: fixing ${issue.message}');
            try {
              await issue.fix!();
            } catch (e) {
              logger.warn('doctor: fix failed for "${issue.message}": $e');
            }
          }
          issues = await v.validate();
        }
      }
      outcomes.add(ValidatorOutcome(validator: v, issues: issues));
    }
    return DoctorResult(outcomes: outcomes);
  }
}
