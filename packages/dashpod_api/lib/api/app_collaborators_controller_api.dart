import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/create_app_collaborator_request_dto.dart';
import 'package:dashpod_api/src/models/update_app_collaborator_request_dto.dart';

/// Endpoints with tag app-collaborators-controller
class AppCollaboratorsControllerApi {
  AppCollaboratorsControllerApi(ApiClient? client)
    : client = client ?? ApiClient();

  final ApiClient client;

  Future<dynamic> add(
    String appId,
    CreateAppCollaboratorRequestDto createAppCollaboratorRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/apps/{appId}/collaborators'.replaceAll(
        '{appId}',
        appId,
      ),
      body: createAppCollaboratorRequestDto.toJson(),
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

  Future<dynamic> update2(
    String appId,
    int collaboratorId,
    UpdateAppCollaboratorRequestDto updateAppCollaboratorRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.patch,
      path: '/api/v1/apps/{appId}/collaborators/{collaboratorId}'
          .replaceAll('{appId}', appId)
          .replaceAll('{collaboratorId}', '$collaboratorId'),
      body: updateAppCollaboratorRequestDto.toJson(),
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
