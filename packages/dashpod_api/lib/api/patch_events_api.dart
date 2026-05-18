import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/patch_events/create_patch_event_request_dto.dart';

part 'patch_events_api.g.dart';

/// Endpoints with tag patch-events-controller
@RestApi()
abstract class PatchEventsApi {
  factory PatchEventsApi(Dio dio) => _PatchEventsApi(dio);

  @POST('/api/v1/patches/events')
  Future<dynamic> createEvent(
    @Body() CreatePatchEventRequestDto createPatchEventRequestDto,
  );
}
