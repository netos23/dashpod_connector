import 'package:dio/dio.dart';

import 'auth_client.dart';

/// Injects the current access token on every request and transparently
/// retries once on 401/403 after refreshing the token.
///
/// Modelled on the reference admin-app interceptor (queued so concurrent
/// requests collapse onto a single in-flight refresh).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required AuthClient authClient}) : _auth = authClient;

  final AuthClient _auth;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _auth.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    if (status != 401 && status != 403) {
      handler.next(err);
      return;
    }
    if (!_auth.isAuthorized) {
      handler.next(err);
      return;
    }
    try {
      await _auth.refresh();
      final retried = await _retry(err.requestOptions);
      handler.resolve(retried);
    } on DioException catch (retryError) {
      handler.reject(retryError);
    } catch (_) {
      // Refresh failed (token revoked / network) — surface the original
      // 401 so the caller sees the auth failure, not a retry failure.
      handler.reject(err);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final dio = Dio();
    try {
      final headers = Map<String, dynamic>.of(options.headers);
      final token = _auth.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      return await dio.request<dynamic>(
        options.uri.toString(),
        data: options.data,
        queryParameters: options.queryParameters,
        options: Options(method: options.method, headers: headers),
      );
    } finally {
      dio.close();
    }
  }
}
