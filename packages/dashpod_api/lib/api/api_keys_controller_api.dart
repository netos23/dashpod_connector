import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/create_api_key_request_dto.dart';
import 'package:dashpod_api/src/models/create_api_key_response_dto.dart';
import 'package:dashpod_api/src/models/get_api_keys_response_dto.dart';

/// Endpoints with tag api-keys-controller
class ApiKeysControllerApi {
  ApiKeysControllerApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  Future<GetApiKeysResponseDto> list() async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/api/v1/users/me/api-keys',
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return GetApiKeysResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<CreateApiKeyResponseDto> create(
    CreateApiKeyRequestDto createApiKeyRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/users/me/api-keys',
      body: createApiKeyRequestDto.toJson(),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return CreateApiKeyResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<dynamic> revoke(int keyId) async {
    final response = await client.invokeApi(
      method: Method.delete,
      path: '/api/v1/users/me/api-keys/{keyId}'.replaceAll(
        '{keyId}',
        '$keyId',
      ),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return jsonDecode(response.body);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
