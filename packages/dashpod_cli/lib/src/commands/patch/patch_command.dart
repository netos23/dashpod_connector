import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dashpod_api/dashpod_api.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../api/api_client.dart';
import '../../archive_diff/android_archive_differ.dart';
import '../../archive_diff/archive_differ.dart';
import '../../artifact_builder/artifact_builder.dart';
import '../../artifact_manager/artifact_manager.dart';
import '../../cache/cache.dart';
import '../../cache/patch_binary.dart';
import '../../code_signer/code_signer.dart';
import '../../command_runner.dart';
import '../../config/dashpod_yaml.dart';
import '../../env/dashpod_env.dart';
import '../../io/console.dart';
import '../../json/json_output.dart';
import '../../logger/logger.dart';
import '../../patch_diff_checker/patch_diff_checker.dart';
import '../../process/dashpod_process.dart';
import '../../telemetry/create_patch_metadata.dart';
import '../../telemetry/update_release_metadata.dart';
import '../dashpod_command.dart';
import 'android_patcher.dart';
import 'patcher.dart';

/// `dashpod patch` — parent command. Real work in per-platform subcommands.
class PatchCommand extends Command<int> {
  PatchCommand({
    required DashpodEnv env,
    required ConsoleIo console,
    required Logger logger,
    required JsonOutputSink json,
    required DashpodApiClientFactory apiClientFactory,
    required DashpodProcess process,
    required Cache cache,
  }) {
    addSubcommand(AndroidPatchSubcommand(
      env: env,
      console: console,
      logger: logger,
      json: json,
      apiClientFactory: apiClientFactory,
      process: process,
      cache: cache,
    ));
  }

  @override
  String get name => 'patch';

  @override
  String get description =>
      'Build and publish an OTA patch against an existing release.';
}

/// `dashpod patch android` — drives [AndroidPatcher] end-to-end.
class AndroidPatchSubcommand extends DashpodCommand {
  AndroidPatchSubcommand({
    required super.env,
    required super.console,
    required super.logger,
    required super.json,
    required DashpodApiClientFactory apiClientFactory,
    required DashpodProcess process,
    required Cache cache,
    DashpodYamlIo? yamlIo,
    ArtifactBuilder? builder,
    ArtifactManager? artifacts,
  })  : _apiClientFactory = apiClientFactory,
        _process = process,
        _cache = cache,
        _yamlIo = yamlIo ?? const DashpodYamlIo(),
        _builderOverride = builder,
        _artifactsOverride = artifacts {
    argParser
      ..addOption(
        'flavor',
        help: 'Flutter flavor to build (must match dashpod.yaml flavors).',
      )
      ..addOption(
        'release-version',
        help: 'Release version to patch ("latest" or "<name>+<code>"). '
            'When omitted, the version is inferred from the built patch artifact.',
      )
      ..addOption(
        'track',
        defaultsTo: 'stable',
        help: 'Deployment channel to publish to (auto-created if missing).',
      )
      ..addMultiOption(
        'target-platform',
        defaultsTo: const [
          'android-arm64',
          'android-arm',
          'android-x64',
        ],
        allowed: const ['android-arm64', 'android-arm', 'android-x64'],
        help: 'Target ABIs to bundle into the patch AAB.',
      )
      ..addFlag(
        'obfuscate',
        negatable: false,
        help: 'Pass --obfuscate to flutter build.',
      )
      ..addFlag(
        'allow-asset-changes',
        negatable: false,
        help: 'Continue even if assets diverged from the release. The OTA '
            'patch will NOT carry those changes.',
      )
      ..addFlag(
        'allow-native-changes',
        negatable: false,
        help: 'Continue even if native code (DEX) diverged from the release. '
            'The OTA patch will NOT carry those changes.',
      )
      ..addOption(
        'private-key',
        help: 'Path to a PEM-encoded RSA private key used to sign patch hashes.',
      )
      ..addOption(
        'public-key',
        help: 'Path to a PEM-encoded RSA public key. Required by --sign-cmd.',
      )
      ..addOption(
        'sign-cmd',
        help: 'External signer command. Receives the hex hash on stdin and '
            'must print the base64 signature on stdout.',
      );
  }

  @override
  String get name => 'android';

  @override
  String get description =>
      'Build a patch AAB, diff against the release, and publish.';

  final DashpodApiClientFactory _apiClientFactory;
  final DashpodProcess _process;
  final Cache _cache;
  final DashpodYamlIo _yamlIo;
  final ArtifactBuilder? _builderOverride;
  final ArtifactManager? _artifactsOverride;

  @override
  Future<int> run() async {
    final results = argResults!;
    final flavor = results['flavor'] as String?;
    final releaseVersionArg = results['release-version'] as String?;
    final track = results['track'] as String;
    final targetPlatforms = results['target-platform'] as List<String>;
    final obfuscate = results['obfuscate'] as bool;
    final allowAssetChanges = results['allow-asset-changes'] as bool;
    final allowNativeChanges = results['allow-native-changes'] as bool;
    final privateKeyArg = results['private-key'] as String?;
    final publicKeyArg = results['public-key'] as String?;
    final signCmdArg = results['sign-cmd'] as String?;

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
        'Flavor "$flavor" is not declared in dashpod.yaml.',
      );
    }

    final CodeSigner? signer;
    try {
      signer = _resolveSigner(
        privateKeyPath: privateKeyArg,
        publicKeyPath: publicKeyArg,
        signCmd: signCmdArg,
      );
    } on CodeSignerException catch (e) {
      return _fail(JsonErrorCode.usageError, e.message);
    } on FormatException catch (e) {
      return _fail(JsonErrorCode.usageError, e.message);
    }

    try {
      await _cache.updateAll();
    } catch (e) {
      logger.warn('Cache update skipped: $e');
    }

    final api = _apiClientFactory(env);
    final artifacts = _artifactsOverride ?? ArtifactManager();
    final builder = _builderOverride ??
        ArtifactBuilder(env: env, process: _process, logger: logger);

    final context = PatchContext(
      env: env,
      logger: logger,
      api: api,
      artifacts: artifacts,
      dashpodYaml: dashpodYaml,
      projectRoot: projectRoot,
      flavor: flavor,
      releaseVersionOverride: releaseVersionArg,
      allowAssetChanges: allowAssetChanges,
      allowNativeChanges: allowNativeChanges,
      track: track,
      signer: signer,
      diffChecker: PatchDiffChecker(
        env: env,
        console: console,
        logger: logger,
      ),
    );

    final patcher = AndroidPatcher(
      context,
      builder: builder,
      patchBinary: PatchBinary(cache: _cache),
      archs: _archsFromTargetPlatforms(targetPlatforms),
      obfuscate: obfuscate,
    );

    // Build first (may be invoked before we know the release version).
    final File patchArtifact;
    try {
      patchArtifact = await patcher.buildPatchArtifact(
        releaseVersion: releaseVersionArg == 'latest' ? null : releaseVersionArg,
      );
    } on ArtifactBuildException catch (e) {
      return _fail(JsonErrorCode.processExit, e.message);
    }

    // Resolve / infer release version.
    String resolvedVersion;
    var inferredReleaseVersion = false;
    if (releaseVersionArg != null && releaseVersionArg != 'latest') {
      resolvedVersion = releaseVersionArg;
    } else {
      try {
        resolvedVersion = await patcher.extractReleaseVersionFromArtifact(patchArtifact);
        inferredReleaseVersion = true;
        logger.info('Inferred release version from artifact: $resolvedVersion');
      } on ArtifactManagerException catch (e) {
        return _fail(JsonErrorCode.softwareError, e.message);
      }
    }

    final int releaseId;
    final String? releaseArchiveUrl;
    try {
      final lookup = await _findReleaseByVersion(
        api: api,
        appId: context.appId,
        version: resolvedVersion,
      );
      releaseId = lookup.releaseId;
      releaseArchiveUrl = lookup.aabUrl;
    } catch (e) {
      return _fail(JsonErrorCode.fetchFailed, e.toString());
    }

    // Download release AAB for diff-check.
    final releaseAab = await _downloadReleaseAab(
      url: releaseArchiveUrl,
      workDir: Directory(p.join(
        projectRoot.path,
        'build',
        'dashpod',
        'patch_android',
      ))
        ..createSync(recursive: true),
    );

    final DiffStatus diffStatus;
    try {
      diffStatus = await context.diffChecker!.confirmUnpatchableDiffsIfNecessary(
        releaseArchive: releaseAab,
        patchArchive: patchArtifact,
        differ: const AndroidArchiveDiffer(),
        allowAssetChanges: allowAssetChanges,
        allowNativeChanges: allowNativeChanges,
      );
    } on UnpatchableChangeException catch (e) {
      return _fail(JsonErrorCode.softwareError, e.message);
    } on UserCancelledException catch (e) {
      return _fail(JsonErrorCode.softwareError, e.message);
    }

    // Build per-arch bundles + create patch + upload.
    final Map<String, PatchArtifactBundle> bundles;
    try {
      bundles = await patcher.createPatchArtifacts(
        appId: context.appId,
        releaseId: releaseId,
        patchArtifact: patchArtifact,
      );
    } catch (e) {
      return _fail(JsonErrorCode.softwareError, 'Failed to build patch bundles: $e');
    }

    final baseMetadata = CreatePatchMetadata(
      releasePlatform: 'android',
      hasAssetChanges: diffStatus.hasAssetChanges,
      hasNativeChanges: diffStatus.hasNativeChanges,
      inferredReleaseVersion: inferredReleaseVersion,
      environment: UpdateReleaseMetadataEnvironment.detect(),
      cliVersion: cliVersion,
    );
    final metadata = await patcher.updatedCreatePatchMetadata(baseMetadata);

    final int patchId;
    final int? patchNumber;
    try {
      final created = await api.patches.createPatch(
        context.appId,
        CreatePatchRequestDto(
          releaseId: releaseId,
          metadata: metadata.toJson(),
        ),
      );
      patchId = created.id ??
          (throw StateError('Server response missing patch id.'));
      patchNumber = created.number;
    } catch (e) {
      return _fail(JsonErrorCode.fetchFailed, 'Failed to create patch row: $e');
    }

    try {
      await patcher.uploadPatchArtifacts(
        appId: context.appId,
        patchId: patchId,
        artifacts: bundles,
      );
    } catch (e) {
      return _fail(JsonErrorCode.fetchFailed, 'Patch artifact upload failed: $e');
    }

    // Auto-create channel and promote.
    final int channelId;
    try {
      channelId = await _resolveOrCreateChannel(
        api: api,
        appId: context.appId,
        name: track,
      );
      await api.patches.createPromote(
        context.appId,
        PromotePatchRequestDto(patchId: patchId, channelId: channelId),
      );
    } catch (e) {
      return _fail(
        JsonErrorCode.fetchFailed,
        'Failed to promote patch to channel "$track": $e',
      );
    }

    final envelope = <String, Object?>{
      'patch_id': patchId,
      'number': patchNumber,
      'release_id': releaseId,
      'app_id': context.appId,
      'channel': track,
      'inferred_release_version': inferredReleaseVersion,
      'has_asset_changes': diffStatus.hasAssetChanges,
      'has_native_changes': diffStatus.hasNativeChanges,
      'artifacts': [
        for (final b in bundles.values)
          {
            'arch': b.arch,
            'size': b.size,
            'hash': b.hash,
            'signed': b.hashSignature != null,
          }
      ],
    };

    if (isJsonMode) {
      return emitJsonSuccess(data: envelope);
    }
    logger.info('Patch #${patchNumber ?? patchId} published.');
    logger.info('  release_id: $releaseId');
    logger.info('  channel: $track');
    for (final b in bundles.values) {
      logger.info('  ${b.arch} ${b.size}B sha256=${b.hash} '
          'signed=${b.hashSignature != null}');
    }
    return 0;
  }

  CodeSigner? _resolveSigner({
    String? privateKeyPath,
    String? publicKeyPath,
    String? signCmd,
  }) {
    if (signCmd != null) {
      if (publicKeyPath == null) {
        throw const FormatException(
          '--sign-cmd requires --public-key for round-trip verification.',
        );
      }
      final pubFile = File(publicKeyPath);
      if (!pubFile.existsSync()) {
        throw FormatException('--public-key file not found: $publicKeyPath');
      }
      return ExternalCommandCodeSigner(
        command: signCmd,
        publicKey: decodePublicKeyPem(pubFile.readAsStringSync()),
      );
    }
    if (privateKeyPath != null) {
      final f = File(privateKeyPath);
      if (!f.existsSync()) {
        throw FormatException('--private-key file not found: $privateKeyPath');
      }
      return PemCodeSigner.fromPrivateKeyFile(f);
    }
    return null;
  }

  Future<_ReleaseLookup> _findReleaseByVersion({
    required DashpodApiClient api,
    required String appId,
    required String version,
  }) async {
    final response = await api.releases.listReleases(appId, null);
    final releases = response.releases ?? const <ReleaseDto>[];
    final matches = [
      for (final r in releases) if (r.version == version) r,
    ];
    if (matches.isEmpty) {
      throw StateError('No release found with version "$version".');
    }
    final release = matches.first;
    final id = release.id;
    if (id == null) {
      throw StateError('Release for "$version" has no id.');
    }
    final artifacts = await api.releases.listArtifacts(
      appId,
      id,
      'aab',
      ListArtifactsParameter3.android,
    );
    final aab = (artifacts.artifacts ?? const <ReleaseArtifactDto>[])
        .firstWhere(
      (a) => a.arch == 'aab',
      orElse: () => throw StateError(
        'Release #$id does not have an aab artifact uploaded yet.',
      ),
    );
    return _ReleaseLookup(releaseId: id, aabUrl: aab.url);
  }

  Future<File> _downloadReleaseAab({
    required String? url,
    required Directory workDir,
  }) async {
    if (url == null || url.isEmpty) {
      throw StateError('Release aab artifact is missing a download URL.');
    }
    final dest = File(p.join(workDir.path, 'release.aab'));
    if (dest.existsSync()) dest.deleteSync();
    logger.detail('Downloading release aab from $url');
    final dio = Dio();
    final res = await dio.download(url, dest.path);
    final code = res.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw StateError('Failed to download release aab: HTTP $code.');
    }
    return dest;
  }

  Future<int> _resolveOrCreateChannel({
    required DashpodApiClient api,
    required String appId,
    required String name,
  }) async {
    final existing = await api.channels.listChannels(appId);
    for (final c in existing) {
      if (c.name == name && c.id != null) return c.id!;
    }
    final created = await api.channels.createChannel(
      appId,
      CreateChannelRequestDto(channel: name),
    );
    final id = created.id;
    if (id == null) {
      throw StateError('Server did not return an id for channel "$name".');
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

class _ReleaseLookup {
  _ReleaseLookup({required this.releaseId, required this.aabUrl});
  final int releaseId;
  final String? aabUrl;
}
