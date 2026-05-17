import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/patch_check_request_dto.dart';
import 'package:dashpod_api/src/models/patch_check_response_dto.dart';

/// Endpoints with tag patch-check-controller
class PatchCheckControllerApi {
  PatchCheckControllerApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  Future<PatchCheckResponseDto> check(
    PatchCheckRequestDto patchCheckRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/patches/check',
      body: patchCheckRequestDto.toJson(),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return PatchCheckResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
