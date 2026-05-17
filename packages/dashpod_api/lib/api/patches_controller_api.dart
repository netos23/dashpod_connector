import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/create_patch_artifact_request_dto.dart';
import 'package:dashpod_api/src/models/create_patch_artifact_response_dto.dart';
import 'package:dashpod_api/src/models/create_patch_request_dto.dart';
import 'package:dashpod_api/src/models/create_patch_response_dto.dart';
import 'package:dashpod_api/src/models/promote_patch_request_dto.dart';

/// Endpoints with tag patches-controller
class PatchesControllerApi {
  PatchesControllerApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  Future<CreatePatchArtifactResponseDto> createArtifact1(
    String appId,
    int patchId,
    CreatePatchArtifactRequestDto createPatchArtifactRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/apps/{appId}/patches/{patchId}/artifacts'
          .replaceAll('{appId}', appId)
          .replaceAll('{patchId}', '$patchId'),
      body: createPatchArtifactRequestDto.toJson(),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return CreatePatchArtifactResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<dynamic> promote(
    String appId,
    PromotePatchRequestDto promotePatchRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/apps/{appId}/patches/promote'.replaceAll(
        '{appId}',
        appId,
      ),
      body: promotePatchRequestDto.toJson(),
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

  Future<CreatePatchResponseDto> create3(
    String appId,
    CreatePatchRequestDto createPatchRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/apps/{appId}/patches'.replaceAll('{appId}', appId),
      body: createPatchRequestDto.toJson(),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return CreatePatchResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
