import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/patches/create_patch_artifact_request_dto.dart';
import 'package:dashpod_api/src/models/patches/create_patch_artifact_response_dto.dart';
import 'package:dashpod_api/src/models/patches/create_patch_request_dto.dart';
import 'package:dashpod_api/src/models/patches/create_patch_response_dto.dart';
import 'package:dashpod_api/src/models/patches/promote_patch_request_dto.dart';

part 'patches_api.g.dart';

/// Endpoints with tag patches-controller
@RestApi()
abstract class PatchesApi {
  factory PatchesApi(Dio dio) => _PatchesApi(dio);

  @POST('/api/v1/apps/{appId}/patches/{patchId}/artifacts')
  Future<CreatePatchArtifactResponseDto> createArtifact(
    @Path('appId') String appId,
    @Path('patchId') int patchId,
    @Body() CreatePatchArtifactRequestDto createPatchArtifactRequestDto,
  );

  @POST('/api/v1/apps/{appId}/patches/promote')
  Future<dynamic> createPromote(
    @Path('appId') String appId,
    @Body() PromotePatchRequestDto promotePatchRequestDto,
  );

  @POST('/api/v1/apps/{appId}/patches')
  Future<CreatePatchResponseDto> createPatch(
    @Path('appId') String appId,
    @Body() CreatePatchRequestDto createPatchRequestDto,
  );
}
