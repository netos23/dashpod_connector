import 'dart:convert';
import 'dart:io';

import 'package:openid_client/openid_client.dart';
import 'package:path/path.dart' as p;

/// File-backed credential store.
///
/// Persists the full `Credential.toJson()` payload, which includes the
/// issuer metadata and client id/secret as well as the access/refresh
/// tokens. That means a saved credential can be restored without
/// re-discovering the OIDC issuer (one less network call on startup, and
/// commands stay usable while offline so long as the access token is
/// still valid).
class CredentialStorage {
  CredentialStorage({required this.file});

  /// Default location: `<config-dir>/credentials.json` (typically
  /// `~/.config/dashpod/credentials.json` on Linux/macOS, `%APPDATA%\dashpod\`
  /// on Windows).
  factory CredentialStorage.inDirectory(Directory configDir) {
    return CredentialStorage(
      file: File(p.join(configDir.path, 'credentials.json')),
    );
  }

  final File file;

  bool exists() => file.existsSync();

  /// Returns the persisted credential, or null if no file exists yet.
  /// A malformed file is treated as "no credential" but is *not* deleted
  /// automatically — surface the parse failure to the caller for logging.
  Credential? load() {
    if (!file.existsSync()) return null;
    final raw = file.readAsStringSync();
    if (raw.trim().isEmpty) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return Credential.fromJson(json);
  }

  void save(Credential credential) {
    file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(credential.toJson()), flush: true);
    tmp.renameSync(file.path);
  }

  void delete() {
    if (file.existsSync()) file.deleteSync();
  }
}
