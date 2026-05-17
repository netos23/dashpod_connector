import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/create_user_request_dto.dart';
import 'package:dashpod_api/src/models/user_dto.dart';

/// Endpoints with tag users-controller
class UsersControllerApi {
  UsersControllerApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  Future<UserDto> create1(CreateUserRequestDto createUserRequestDto) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/users',
      body: createUserRequestDto.toJson(),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return UserDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<UserDto> me() async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/api/v1/users/me',
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return UserDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
