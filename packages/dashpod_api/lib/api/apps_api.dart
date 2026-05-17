import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/apps/app_dto.dart';
import 'package:dashpod_api/src/models/apps/create_app_request_dto.dart';
import 'package:dashpod_api/src/models/apps/get_apps_response_dto.dart';

part 'apps_api.g.dart';

/// Endpoints with tag apps-controller
@RestApi()
abstract class AppsApi {
  factory AppsApi(Dio dio) => _AppsApi(dio);

  @GET('/api/v1/apps')
  Future<GetAppsResponseDto> list4();

  @POST('/api/v1/apps')
  Future<AppDto> create5(@Body() CreateAppRequestDto createAppRequestDto);

  @DELETE('/api/v1/apps/{appId}')
  Future<dynamic> delete(@Path('appId') String appId);
}
