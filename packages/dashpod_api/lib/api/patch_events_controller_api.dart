import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/create_patch_event_request_dto.dart';

part 'patch_events_controller_api.g.dart';

/// Endpoints with tag patch-events-controller
@RestApi()
abstract class PatchEventsControllerApi {
  factory PatchEventsControllerApi(Dio dio) => _PatchEventsControllerApi(dio);

  @POST('/api/v1/patches/events')
  Future<dynamic> report(
    @Body() CreatePatchEventRequestDto createPatchEventRequestDto,
  );
}
