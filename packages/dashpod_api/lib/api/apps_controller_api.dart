import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/app_dto.dart';
import 'package:dashpod_api/src/models/create_app_request_dto.dart';
import 'package:dashpod_api/src/models/get_apps_response_dto.dart';

part 'apps_controller_api.g.dart';

/// Endpoints with tag apps-controller
@RestApi()
abstract class AppsControllerApi {
  factory AppsControllerApi(Dio dio) => _AppsControllerApi(dio);

  @GET('/api/v1/apps')
  Future<GetAppsResponseDto> list3();

  @POST('/api/v1/apps')
  Future<AppDto> create5(@Body() CreateAppRequestDto createAppRequestDto);

  @DELETE('/api/v1/apps/{appId}')
  Future<dynamic> delete(@Path('appId') String appId);
}
