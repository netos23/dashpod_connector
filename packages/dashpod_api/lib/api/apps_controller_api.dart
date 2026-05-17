import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/app_dto.dart';
import 'package:dashpod_api/src/models/create_app_request_dto.dart';
import 'package:dashpod_api/src/models/get_apps_response_dto.dart';

/// Endpoints with tag apps-controller
class AppsControllerApi {
  AppsControllerApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  Future<GetAppsResponseDto> list3() async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/api/v1/apps',
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return GetAppsResponseDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<AppDto> create5(CreateAppRequestDto createAppRequestDto) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/apps',
      body: createAppRequestDto.toJson(),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return AppDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<dynamic> delete(String appId) async {
    final response = await client.invokeApi(
      method: Method.delete,
      path: '/api/v1/apps/{appId}'.replaceAll('{appId}', appId),
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
