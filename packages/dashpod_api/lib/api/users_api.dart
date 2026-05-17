import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/users/create_user_request_dto.dart';
import 'package:dashpod_api/src/models/users/user_dto.dart';

part 'users_api.g.dart';

/// Endpoints with tag users-controller
@RestApi()
abstract class UsersApi {
  factory UsersApi(Dio dio) => _UsersApi(dio);

  @POST('/api/v1/users')
  Future<UserDto> create1(@Body() CreateUserRequestDto createUserRequestDto);

  @GET('/api/v1/users/me')
  Future<UserDto> me();
}
