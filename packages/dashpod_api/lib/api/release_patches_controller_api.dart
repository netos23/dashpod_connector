import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/get_release_patches_response_dto.dart';
import 'package:dashpod_api/src/models/update_patch_request_dto.dart';

part 'release_patches_controller_api.g.dart';

/// Endpoints with tag release-patches-controller
@RestApi()
abstract class ReleasePatchesControllerApi {
  factory ReleasePatchesControllerApi(Dio dio) =>
      _ReleasePatchesControllerApi(dio);

  @PATCH('/api/v1/apps/{appId}/releases/{releaseId}/patches/{patchId}')
  Future<dynamic> update(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
    @Path('patchId') int patchId,
    @Body() UpdatePatchRequestDto updatePatchRequestDto,
  );

  @GET('/api/v1/apps/{appId}/releases/{releaseId}/patches')
  Future<GetReleasePatchesResponseDto> list4(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
  );
}
