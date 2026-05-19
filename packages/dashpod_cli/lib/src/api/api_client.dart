import 'package:dashpod_api/dashpod_api.dart';
import 'package:dio/dio.dart';

import '../auth/auth_client.dart';
import '../auth/auth_interceptor.dart';
import '../env/dashpod_env.dart';

/// Function-typed factory so tests can substitute a stub client without
/// going through Dio at all.
typedef DashpodApiClientFactory = DashpodApiClient Function(DashpodEnv env);

/// Thin wrapper holding the generated Retrofit APIs we need.
///
/// Auth precedence:
///   1. `DASHPOD_TOKEN` env var (static bearer — handy for CI).
///   2. Stored OIDC credential via [AuthClient] when provided; an
///      [AuthInterceptor] handles refresh-on-401 transparently.
class DashpodApiClient {
  DashpodApiClient({
    required this.apps,
    required this.organizations,
    required this.users,
  });

  factory DashpodApiClient.build({
    required DashpodEnv env,
    AuthClient? authClient,
  }) {
    final dio = Dio(BaseOptions(baseUrl: env.hostedUri.toString()));
    final token = env.sessionToken;
    if (token != null && token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    } else if (authClient != null) {
      dio.interceptors.add(AuthInterceptor(authClient: authClient));
    }
    return DashpodApiClient(
      apps: AppsApi(dio),
      organizations: OrganizationsApi(dio),
      users: UsersApi(dio),
    );
  }

  /// Convenience for callers that don't need auth wiring (e.g. read-only
  /// device-facing endpoints, tests).
  static DashpodApiClient fromEnv(DashpodEnv env) =>
      DashpodApiClient.build(env: env);

  final AppsApi apps;
  final OrganizationsApi organizations;
  final UsersApi users;
}
