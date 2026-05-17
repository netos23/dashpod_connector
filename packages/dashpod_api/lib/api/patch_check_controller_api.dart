import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/patch_check_request_dto.dart';
import 'package:dashpod_api/src/models/patch_check_response_dto.dart';

part 'patch_check_controller_api.g.dart';

/// Endpoints with tag patch-check-controller
@RestApi()
abstract class PatchCheckControllerApi {
  factory PatchCheckControllerApi(Dio dio) => _PatchCheckControllerApi(dio);

  @POST('/api/v1/patches/check')
  Future<PatchCheckResponseDto> check(
    @Body() PatchCheckRequestDto patchCheckRequestDto,
  );
}
