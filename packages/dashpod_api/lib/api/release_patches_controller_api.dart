import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/get_release_patches_response_dto.dart';
import 'package:dashpod_api/src/models/update_patch_request_dto.dart';

/// Endpoints with tag release-patches-controller
class ReleasePatchesControllerApi {
  ReleasePatchesControllerApi(ApiClient? client)
    : client = client ?? ApiClient();

  final ApiClient client;

  Future<dynamic> update(
    String appId,
    int releaseId,
    int patchId,
    UpdatePatchRequestDto updatePatchRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/api/v1/apps/{appId}/releases/{releaseId}/patches/{patchId}'
          .replaceAll('{appId}', appId)
          .replaceAll('{releaseId}', '$releaseId')
          .replaceAll('{patchId}', '$patchId'),
      body: updatePatchRequestDto.toJson(),
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

  Future<GetReleasePatchesResponseDto> list4(
    String appId,
    int releaseId,
  ) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/api/v1/apps/{appId}/releases/{releaseId}/patches'
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
      return GetReleasePatchesResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
