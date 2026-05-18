import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/releases/create_release_artifact_request_dto.dart';
import 'package:dashpod_api/src/models/releases/create_release_artifact_response_dto.dart';
import 'package:dashpod_api/src/models/releases/create_release_request_dto.dart';
import 'package:dashpod_api/src/models/releases/create_release_response_dto.dart';
import 'package:dashpod_api/src/models/releases/get_release_artifacts_response_dto.dart';
import 'package:dashpod_api/src/models/releases/get_release_response_dto.dart';
import 'package:dashpod_api/src/models/releases/get_releases_response_dto.dart';
import 'package:dashpod_api/src/models/releases/list_artifacts_parameter3.dart';
import 'package:dashpod_api/src/models/releases/update_release_request_dto.dart';

part 'releases_api.g.dart';

/// Endpoints with tag releases-controller
@RestApi()
abstract class ReleasesApi {
  factory ReleasesApi(Dio dio) => _ReleasesApi(dio);

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
  Future<GetReleasesResponseDto> listReleases(
    @Path('appId') String appId,
    @Query('sideloadable') bool? sideloadable,
  );

  @POST('/api/v1/apps/{appId}/releases')
  Future<CreateReleaseResponseDto> createRelease(
    @Path('appId') String appId,
    @Body() CreateReleaseRequestDto createReleaseRequestDto,
  );

  @GET('/api/v1/apps/{appId}/releases/{releaseId}')
  Future<GetReleaseResponseDto> getRelease(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
  );

  @PATCH('/api/v1/apps/{appId}/releases/{releaseId}')
  Future<dynamic> updateRelease(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
    @Body() UpdateReleaseRequestDto updateReleaseRequestDto,
  );
}
