import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/release_patches/get_release_patches_response_dto.dart';
import 'package:dashpod_api/src/models/release_patches/update_patch_request_dto.dart';

part 'release_patches_api.g.dart';

/// Endpoints with tag release-patches-controller
@RestApi()
abstract class ReleasePatchesApi {
  factory ReleasePatchesApi(Dio dio) => _ReleasePatchesApi(dio);

  @PATCH('/api/v1/apps/{appId}/releases/{releaseId}/patches/{patchId}')
  Future<dynamic> updatePatch(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
    @Path('patchId') int patchId,
    @Body() UpdatePatchRequestDto updatePatchRequestDto,
  );

  @GET('/api/v1/apps/{appId}/releases/{releaseId}/patches')
  Future<GetReleasePatchesResponseDto> listPatches(
    @Path('appId') String appId,
    @Path('releaseId') int releaseId,
  );
}
