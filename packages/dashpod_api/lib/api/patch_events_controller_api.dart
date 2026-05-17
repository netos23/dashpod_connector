import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/create_patch_event_request_dto.dart';

/// Endpoints with tag patch-events-controller
class PatchEventsControllerApi {
  PatchEventsControllerApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  Future<dynamic> report(
    CreatePatchEventRequestDto createPatchEventRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/patches/events',
      body: createPatchEventRequestDto.toJson(),
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
