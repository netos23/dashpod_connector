import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dashpod_api/dashpod_api.dart';
import 'package:flutter_revision/flutter_revision.dart';
import 'package:path/path.dart' as p;

import '../../api/api_client.dart';
import '../../artifact_builder/artifact_builder.dart';
import '../../artifact_manager/artifact_manager.dart';
import '../../command_runner.dart';
import '../../config/dashpod_yaml.dart';
import '../../env/dashpod_env.dart';
import '../../io/console.dart';
import '../../json/json_output.dart';
import '../../logger/logger.dart';
import '../../process/dashpod_process.dart';
import '../../telemetry/update_release_metadata.dart';
import '../dashpod_command.dart';
import 'android_releaser.dart';
import 'releaser.dart';

/// `dashpod release` — parent command. Real work happens in the
/// per-platform subcommands.
class ReleaseCommand extends Command<int> {
  ReleaseCommand({
    required DashpodEnv env,
    required ConsoleIo console,
    required Logger logger,
    required JsonOutputSink json,
    required DashpodApiClientFactory apiClientFactory,
    required DashpodProcess process,
  }) {
    addSubcommand(AndroidReleaseSubcommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      apiClientFactory: apiClientFactory,
      process: process,
    ));
  }

  @override
  String get name => 'release';

  @override
  String get description =>
      'Build and publish a release for the configured app(s).';
}

/// `dashpod release android` — drives [AndroidReleaser] end-to-end.
class AndroidReleaseSubcommand extends DashpodCommand {
  AndroidReleaseSubcommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required DashpodApiClientFactory apiClientFactory,
    required DashpodProcess process,
    DashpodYamlIo? yamlIo,
    ArtifactBuilder? builder,
    ArtifactManager? artifacts,
    FlutterRevisionResolver? flutterResolver,
  })  : _apiClientFactory = apiClientFactory,
        _process = process,
        _yamlIo = yamlIo ?? const DashpodYamlIo(),
        _builderOverride = builder,
        _artifactsOverride = artifacts,
        _flutterResolver = flutterResolver ?? const FlutterRevisionResolver() {
    argParser
      ..addOption(
        'flavor',
        help: 'Flutter flavor to build (must match dashpod.yaml flavors map).',
      )
      ..addMultiOption(
        'target-platform',
        defaultsTo: const [
          'android-arm64',
          'android-arm',
          'android-x64',
        ],
        allowed: const ['android-arm64', 'android-arm', 'android-x64'],
        help: 'Target ABIs to bundle into the .aab.',
      )
      ..addOption('display-name', help: 'Release display name shown in the dashboard.')
      ..addOption('notes', help: 'Release notes attached when going active.')
      ..addOption('build-name', help: 'Override the pubspec build-name (versionName).')
      ..addOption('build-number', help: 'Override the pubspec build-number (versionCode).')
      ..addFlag(
        'obfuscate',
        negatable: false,
        help: 'Pass --obfuscate to flutter build; symbols are kept in '
            'build/dashpod/symbols.',
      );
  }

  @override
  String get name => 'android';

  @override
  String get description =>
      'Build an AAB, register a release, and upload the artifacts.';

  final DashpodApiClientFactory _apiClientFactory;
  final DashpodProcess _process;
  final DashpodYamlIo _yamlIo;
  final ArtifactBuilder? _builderOverride;
  final ArtifactManager? _artifactsOverride;
  final FlutterRevisionResolver _flutterResolver;

  @override
  Future<int> run() async {
    final results = argResults!;
    final flavor = results['flavor'] as String?;
    final targetPlatforms = results['target-platform'] as List<String>;
    final displayNameArg = results['display-name'] as String?;
    final notesArg = results['notes'] as String?;
    final buildName = results['build-name'] as String?;
    final buildNumber = results['build-number'] as String?;
    final obfuscate = results['obfuscate'] as bool;

    final pubspec = env.pubspecFile;
    if (pubspec == null) {
      return _fail(
        JsonErrorCode.softwareError,
        'No pubspec.yaml found in ${env.workingDirectory.path} or any parent.',
      );
    }
    final projectRoot = Directory(p.dirname(pubspec.path));

    final dashpodYamlFile = env.dashpodYamlFile;
    if (!dashpodYamlFile.existsSync()) {
      return _fail(
        JsonErrorCode.softwareError,
        'dashpod.yaml not found at ${dashpodYamlFile.path}. Run `dashpod init` first.',
      );
    }
    late final DashpodYaml dashpodYaml;
    try {
      dashpodYaml = _yamlIo.read(dashpodYamlFile);
    } on FormatException catch (e) {
      return _fail(JsonErrorCode.softwareError, e.message);
    }

    if (flavor != null && !dashpodYaml.flavors.containsKey(flavor)) {
      return _fail(
        JsonErrorCode.usageError,
        'Flavor "$flavor" is not declared in dashpod.yaml. '
        'Known flavors: ${dashpodYaml.flavors.keys.join(', ')}.',
      );
    }

    final archs = _archsFromTargetPlatforms(targetPlatforms);
    final pubspecName = env.readPubspecName(pubspec);
    final displayName = displayNameArg ?? pubspecName;

    final flutterRev = _flutterResolver
        .resolve(projectRoot.path)
        .toVersionArg();

    final api = _apiClientFactory(env);
    final artifacts = _artifactsOverride ?? ArtifactManager();
    final builder = _builderOverride ??
        ArtifactBuilder(env: env, process: _process, logger: logger);

    final context = ReleaseContext(
      env: env,
      logger: logger,
      api: api,
      artifacts: artifacts,
      dashpodYaml: dashpodYaml,
      projectRoot: projectRoot,
      flavor: flavor,
      notes: notesArg,
      displayName: displayName,
      flutterRevision: flutterRev,
      flutterVersion: flutterRev,
    );
    final releaser = AndroidReleaser(
      context,
      builder: builder,
      archs: archs,
      obfuscate: obfuscate,
      buildName: buildName,
      buildNumber: buildNumber,
    );

    try {
      await releaser.assertArgsAreValid();
      await releaser.assertPreconditions();
    } on FormatException catch (e) {
      return _fail(JsonErrorCode.usageError, e.message);
    }

    final File primary;
    try {
      primary = await releaser.buildReleaseArtifacts();
    } on ArtifactBuildException catch (e) {
      return _fail(JsonErrorCode.processExit, e.message);
    }

    final ReleaseVersion version;
    try {
      version = await releaser.extractReleaseVersion(primary);
    } on ArtifactManagerException catch (e) {
      return _fail(JsonErrorCode.softwareError, e.message);
    }
    logger.info('Resolved release version: ${version.wire}');

    final int releaseId;
    try {
      releaseId = await _fetchOrCreateRelease(
        api: api,
        appId: context.appId,
        version: version,
        flutterRevision: flutterRev,
        displayName: displayName,
      );
    } catch (e) {
      return _fail(JsonErrorCode.fetchFailed, 'Failed to create release: $e');
    }

    try {
      await api.releases.updateRelease(
        context.appId,
        releaseId,
        UpdateReleaseRequestDto(
          status: UpdateReleaseRequestDtoStatus.draft,
          platform: UpdateReleaseRequestDtoPlatform.android,
        ),
      );
    } catch (e) {
      return _fail(
        JsonErrorCode.fetchFailed,
        'Failed to mark release #$releaseId as draft: $e',
      );
    }

    List<UploadedArtifact> uploaded;
    try {
      uploaded = await releaser.uploadReleaseArtifacts(
        releaseId: releaseId,
        primaryArtifact: primary,
      );
    } catch (e) {
      return _fail(JsonErrorCode.fetchFailed, 'Artifact upload failed: $e');
    }

    final baseMetadata = UpdateReleaseMetadata(
      releasePlatform: 'android',
      flutterRevision: flutterRev,
      generatedApks: false,
      environment: UpdateReleaseMetadataEnvironment.detect(),
      cliVersion: cliVersion,
    );
    final metadata = await releaser.updatedReleaseMetadata(baseMetadata);

    try {
      await api.releases.updateRelease(
        context.appId,
        releaseId,
        UpdateReleaseRequestDto(
          status: UpdateReleaseRequestDtoStatus.active,
          platform: UpdateReleaseRequestDtoPlatform.android,
          notes: notesArg,
          metadata: metadata.toJson(),
        ),
      );
    } catch (e) {
      return _fail(
        JsonErrorCode.fetchFailed,
        'Failed to finalise release #$releaseId: $e',
      );
    }

    final result = ReleaseResult(
      releaseId: releaseId,
      appId: context.appId,
      version: version,
      platform: 'android',
      uploadedArtifacts: uploaded,
    );

    if (isJsonMode) {
      return emitJsonSuccess(data: result.toJson());
    }
    logger.info('Release #$releaseId published.');
    logger.info('  app_id: ${context.appId}');
    logger.info('  version: ${version.wire}');
    for (final a in uploaded) {
      logger.info('  ${a.arch} ${a.filename} ${a.size}B sha256=${a.hash}');
    }
    if (releaser.postReleaseInstructions.isNotEmpty) {
      logger.info('');
      logger.info(releaser.postReleaseInstructions);
    }
    return 0;
  }

  Future<int> _fetchOrCreateRelease({
    required DashpodApiClient api,
    required String appId,
    required ReleaseVersion version,
    required String flutterRevision,
    String? displayName,
  }) async {
    final existing = await api.releases.listReleases(appId, null);
    for (final r in existing.releases ?? const <ReleaseDto>[]) {
      if (r.version == version.wire && r.id != null) {
        logger.info('Reusing existing release #${r.id} for ${version.wire}.');
        return r.id!;
      }
    }
    logger.info('Creating new release row for ${version.wire}…');
    final created = await api.releases.createRelease(
      appId,
      CreateReleaseRequestDto(
        version: version.wire,
        flutterRevision: flutterRevision,
        flutterVersion: flutterRevision,
        displayName: displayName,
      ),
    );
    final id = created.release?.id;
    if (id == null) {
      throw StateError('Server response did not include a release id.');
    }
    return id;
  }

  List<AndroidArch> _archsFromTargetPlatforms(List<String> raw) {
    return [
      for (final t in raw)
        switch (t) {
          'android-arm64' => AndroidArch.arm64,
          'android-arm' => AndroidArch.arm32,
          'android-x64' => AndroidArch.x86_64,
          _ => throw FormatException('Unknown --target-platform: $t'),
        }
    ];
  }

  int _fail(JsonErrorCode code, String message) {
    if (isJsonMode) {
      return emitJsonError(code: code, message: message);
    }
    logger.err(message);
    return code == JsonErrorCode.usageError ? 64 : 1;
  }
}
