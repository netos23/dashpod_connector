import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dashpod_api/api_client.dart';
import 'package:dashpod_api/api_exception.dart';
import 'package:dashpod_api/src/models/channel_dto.dart';
import 'package:dashpod_api/src/models/create_channel_request_dto.dart';

/// Endpoints with tag channels-controller
class ChannelsControllerApi {
  ChannelsControllerApi(ApiClient? client) : client = client ?? ApiClient();

  final ApiClient client;

  Future<List<ChannelDto>> list2(String appId) async {
    final response = await client.invokeApi(
      method: Method.get,
      path: '/api/v1/apps/{appId}/channels'.replaceAll('{appId}', appId),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return (jsonDecode(response.body) as List)
          .map<ChannelDto>(
            (e) => ChannelDto.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }

  Future<ChannelDto> create4(
    String appId,
    CreateChannelRequestDto createChannelRequestDto,
  ) async {
    final response = await client.invokeApi(
      method: Method.post,
      path: '/api/v1/apps/{appId}/channels'.replaceAll('{appId}', appId),
      body: createChannelRequestDto.toJson(),
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException<Object?>(
        response.statusCode,
        response.body,
      );
    }

    if (response.body.isNotEmpty) {
      return ChannelDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException<Object?>.unhandled(response.statusCode);
  }
}
