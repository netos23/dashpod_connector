import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/create_app_collaborator_request_dto.dart';
import 'package:dashpod_api/src/models/update_app_collaborator_request_dto.dart';

part 'app_collaborators_controller_api.g.dart';

/// Endpoints with tag app-collaborators-controller
@RestApi()
abstract class AppCollaboratorsControllerApi {
  factory AppCollaboratorsControllerApi(Dio dio) =>
      _AppCollaboratorsControllerApi(dio);

  @POST('/api/v1/apps/{appId}/collaborators')
  Future<dynamic> add(
    @Path('appId') String appId,
    @Body() CreateAppCollaboratorRequestDto createAppCollaboratorRequestDto,
  );

  @PATCH('/api/v1/apps/{appId}/collaborators/{collaboratorId}')
  Future<dynamic> update2(
    @Path('appId') String appId,
    @Path('collaboratorId') int collaboratorId,
    @Body() UpdateAppCollaboratorRequestDto updateAppCollaboratorRequestDto,
  );
}
