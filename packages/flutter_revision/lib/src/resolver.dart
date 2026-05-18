import 'errors.dart';
import 'fvm_config_reader.dart';
import 'pubspec_reader.dart';
import 'revision.dart';

void _noop(String _) {}

/// Resolves the Flutter SDK revision for a given package directory.
///
/// Resolution order:
/// 1. `flutter` key in the pubspec.yaml `environment` section.
/// 2. `.fvmrc` (FVM v3) or `.fvm/fvm_config.json` (FVM v2).
/// 3. Fallback: [StableRevision].
///
/// Inject a [LogSink] to receive diagnostic messages during resolution.
final class FlutterRevisionResolver {
  const FlutterRevisionResolver({
    LogSink log = _noop,
    PubspecFlutterVersionReader reader = const PubspecFlutterVersionReader(),
    FvmConfigReader fvmReader = const FvmConfigReader(),
  })  : _log = log,
        _reader = reader,
        _fvmReader = fvmReader;

  final LogSink _log;
  final PubspecFlutterVersionReader _reader;
  final FvmConfigReader _fvmReader;

  /// Resolves the Flutter revision for the package at [packagePath].
  ///
  /// Always returns a [FlutterRevision] — never throws.
  FlutterRevision resolve(String packagePath) {
    _log('Resolving Flutter revision for $packagePath');
    _log('Checking pubspec.yaml environment section');

    try {
      final version = _reader.read(packagePath);
      if (version != null) {
        _log('Found pinned Flutter version in pubspec.yaml: $version');
        return PinnedRevision(version);
      }
    } on PubspecVersionConstraintException catch (e) {
      _log(
        'Found version constraint: ${e.constraint}. '
        'Version constraints are not supported — '
        'specify an exact version. Falling back to stable.',
      );
      return const StableRevision();
    } on Exception catch (e) {
      _log('Error reading pubspec.yaml: $e');
      _log('Falling back to stable channel');
      return const StableRevision();
    }

    _log('Checking FVM configuration (.fvmrc / .fvm/fvm_config.json)');

    try {
      final fvmVersion = _fvmReader.read(packagePath);
      if (fvmVersion != null) {
        _log('Found pinned Flutter version in FVM config: $fvmVersion');
        return PinnedRevision(fvmVersion);
      }
    } on Exception catch (e) {
      _log('Error reading FVM config: $e');
    }

    _log('No Flutter version pinned in pubspec.yaml or FVM config — using stable channel');
    return const StableRevision();
  }
}