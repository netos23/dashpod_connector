import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/app_collaborators/create_app_collaborator_request_dto.dart';
import 'package:dashpod_api/src/models/app_collaborators/get_app_collaborators_response_dto.dart';
import 'package:dashpod_api/src/models/app_collaborators/update_app_collaborator_request_dto.dart';

part 'app_collaborators_api.g.dart';

/// Endpoints with tag app-collaborators-controller
@RestApi()
abstract class AppCollaboratorsApi {
  factory AppCollaboratorsApi(Dio dio) => _AppCollaboratorsApi(dio);

  @GET('/api/v1/apps/{appId}/collaborators')
  Future<GetAppCollaboratorsResponseDto> list2(@Path('appId') String appId);

  @POST('/api/v1/apps/{appId}/collaborators')
  Future<dynamic> add(
    @Path('appId') String appId,
    @Body() CreateAppCollaboratorRequestDto createAppCollaboratorRequestDto,
  );

  @DELETE('/api/v1/apps/{appId}/collaborators/{collaboratorId}')
  Future<dynamic> remove(
    @Path('appId') String appId,
    @Path('collaboratorId') int collaboratorId,
  );

  @PATCH('/api/v1/apps/{appId}/collaborators/{collaboratorId}')
  Future<dynamic> update2(
    @Path('appId') String appId,
    @Path('collaboratorId') int collaboratorId,
    @Body() UpdateAppCollaboratorRequestDto updateAppCollaboratorRequestDto,
  );
}
