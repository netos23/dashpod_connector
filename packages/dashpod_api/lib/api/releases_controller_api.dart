import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/create_release_artifact_request_dto.dart';
import 'package:dashpod_api/src/models/create_release_artifact_response_dto.dart';
import 'package:dashpod_api/src/models/create_release_request_dto.dart';
import 'package:dashpod_api/src/models/create_release_response_dto.dart';
import 'package:dashpod_api/src/models/get_release_artifacts_response_dto.dart';
import 'package:dashpod_api/src/models/get_release_response_dto.dart';
import 'package:dashpod_api/src/models/get_releases_response_dto.dart';
import 'package:dashpod_api/src/models/list_artifacts_parameter3.dart';
import 'package:dashpod_api/src/models/update_release_request_dto.dart';

part 'releases_controller_api.g.dart';

/// Endpoints with tag releases-controller
@RestApi()
abstract class ReleasesControllerApi {
  factory ReleasesControllerApi(Dio dio) => _ReleasesControllerApi(dio);

  @GET('/api/v1/apps/{appId}/releases/{releaseId}/artifacts')
  Future<GetReleaseArtifactsResponseDto> listArtifacts(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
    @Query('arch') String? arch,
    @Query('platform') ListArtifactsParameter3? platform,
  );

  @POST('/api/v1/apps/{appId}/releases/{releaseId}/artifacts')
  Future<CreateReleaseArtifactResponseDto> createArtifact(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
    @Body() CreateReleaseArtifactRequestDto createReleaseArtifactRequestDto,
  );

  @GET('/api/v1/apps/{appId}/releases')
  Future<GetReleasesResponseDto> list1(
    @Path('appId') String appId,
    @Query('sideloadable') bool? sideloadable,
  );

  @POST('/api/v1/apps/{appId}/releases')
  Future<CreateReleaseResponseDto> create2(
    @Path('appId') String appId,
    @Body() CreateReleaseRequestDto createReleaseRequestDto,
  );

  @GET('/api/v1/apps/{appId}/releases/{releaseId}')
  Future<GetReleaseResponseDto> get(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
  );

  @PATCH('/api/v1/apps/{appId}/releases/{releaseId}')
  Future<dynamic> update1(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
    @Body() UpdateReleaseRequestDto updateReleaseRequestDto,
  );
}
