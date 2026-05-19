/// Severity of a [ValidationIssue].
///
/// `error` keeps the host project broken until fixed; `warning` is worth
/// noticing but does not block; `info` is purely advisory (used for
/// "we detected X — heads up" notes).
enum ValidationIssueSeverity { error, warning, info }

/// One outcome from a [Validator] run.
class ValidationIssue {
  ValidationIssue({
    required this.severity,
    required this.message,
    this.displayMessage,
    this.fix,
  });

  final ValidationIssueSeverity severity;

  /// One-line problem description (machine-friendly; goes into JSON).
  final String message;

  /// Optional richer description shown in the terminal. May contain
  /// newlines and longer prose. Defaults to [message] when null.
  final String? displayMessage;

  /// Callback invoked when the user passes `--fix`. `null` means the
  /// issue has no automatic remediation.
  final Future<void> Function()? fix;

  bool get hasFix => fix != null;

  Map<String, Object?> toJson() => {
        'severity': severity.name,
        'message': message,
        if (displayMessage != null) 'display_message': displayMessage,
        'has_fix': hasFix,
      };
}

/// A single check the `dashpod doctor` runner can execute.
///
/// Implementations are sync to construct so the runner can build them
/// up-front. `validate()` is async because most checks touch disk.
abstract class Validator {
  const Validator();

  /// Human-readable label printed in `doctor` output.
  String get description;

  /// Returns false when the validator simply cannot run here (e.g. an
  /// iOS-only validator on Linux, or a project-scoped validator outside
  /// of a project). The runner skips it without surfacing an error.
  bool canRunInCurrentContext() => true;

  /// Reason shown when [canRunInCurrentContext] returns false.
  String get incorrectContextMessage =>
      '$description cannot run in this context.';

  /// Performs the check. Returns an empty list when everything is OK.
  Future<List<ValidationIssue>> validate();
}
