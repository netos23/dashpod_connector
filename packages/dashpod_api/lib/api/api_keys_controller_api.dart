import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/create_api_key_request_dto.dart';
import 'package:dashpod_api/src/models/create_api_key_response_dto.dart';
import 'package:dashpod_api/src/models/get_api_keys_response_dto.dart';

part 'api_keys_controller_api.g.dart';

/// Endpoints with tag api-keys-controller
@RestApi()
abstract class ApiKeysControllerApi {
  factory ApiKeysControllerApi(Dio dio) => _ApiKeysControllerApi(dio);

  @GET('/api/v1/users/me/api-keys')
  Future<GetApiKeysResponseDto> list();

  @POST('/api/v1/users/me/api-keys')
  Future<CreateApiKeyResponseDto> create(
    @Body() CreateApiKeyRequestDto createApiKeyRequestDto,
  );

  @DELETE('/api/v1/users/me/api-keys/{keyId}')
  Future<dynamic> revoke(@Path('keyId') int keyId);
}
