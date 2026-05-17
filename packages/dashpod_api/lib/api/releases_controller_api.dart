import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/create_release_artifact_request_dto.dart';
import 'package:dashpod_api/src/models/create_release_artifact_response_dto.dart';
import 'package:dashpod_api/src/models/create_release_request_dto.dart';
import 'package:dashpod_api/src/models/create_release_response_dto.dart';
import 'package:dashpod_api/src/models/get_release_artifacts_response_dto.dart';
import 'package:dashpod_api/src/models/get_release_response_dto.dart';
import 'package:dashpod_api/src/models/get_releases_response_dto.dart';
import 'package:dashpod_api/src/models/list_artifacts_parameter3.dart';
import 'package:dashpod_api/src/models/update_release_request_dto.dart';

/// Endpoints with tag releases-controller
class ReleasesControllerApi {
  ReleasesControllerApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  Future<GetReleaseArtifactsResponseDto> listArtifacts(
    String appId,
    int releaseId, {
    String? arch,
    ListArtifactsParameter3? platform,
  }) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/api/v1/apps/{appId}/releases/{releaseId}/artifacts'
          .replaceAll('{appId}', appId)
          .replaceAll('{releaseId}', '$releaseId'),
      queryParameters: {
        if (arch != null) 'arch': [arch],
        if (platform != null) 'platform': [platform.toJson()],
      },
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return GetReleaseArtifactsResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<CreateReleaseArtifactResponseDto> createArtifact(
    String appId,
    int releaseId,
    CreateReleaseArtifactRequestDto createReleaseArtifactRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/apps/{appId}/releases/{releaseId}/artifacts'
          .replaceAll('{appId}', appId)
          .replaceAll('{releaseId}', '$releaseId'),
      body: createReleaseArtifactRequestDto.toJson(),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return CreateReleaseArtifactResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<GetReleasesResponseDto> list1(
    String appId, {
    bool? sideloadable,
  }) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/api/v1/apps/{appId}/releases'.replaceAll('{appId}', appId),
      queryParameters: {
        if (sideloadable != null) 'sideloadable': [sideloadable.toString()],
      },
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return GetReleasesResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<CreateReleaseResponseDto> create2(
    String appId,
    CreateReleaseRequestDto createReleaseRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/apps/{appId}/releases'.replaceAll('{appId}', appId),
      body: createReleaseRequestDto.toJson(),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return CreateReleaseResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<GetReleaseResponseDto> get(String appId, int releaseId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/api/v1/apps/{appId}/releases/{releaseId}'
          .replaceAll('{appId}', appId)
          .replaceAll('{releaseId}', '$releaseId'),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return GetReleaseResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<dynamic> update1(
    String appId,
    int releaseId,
    UpdateReleaseRequestDto updateReleaseRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/api/v1/apps/{appId}/releases/{releaseId}'
          .replaceAll('{appId}', appId)
          .replaceAll('{releaseId}', '$releaseId'),
      body: updateReleaseRequestDto.toJson(),
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
