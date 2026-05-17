import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/channel_dto.dart';
import 'package:dashpod_api/src/models/create_channel_request_dto.dart';

part 'channels_controller_api.g.dart';

/// Endpoints with tag channels-controller
@RestApi()
abstract class ChannelsControllerApi {
  factory ChannelsControllerApi(Dio dio) => _ChannelsControllerApi(dio);

  @GET('/api/v1/apps/{appId}/channels')
  Future<List<ChannelDto>> list2(@Path('appId') String appId);

  @POST('/api/v1/apps/{appId}/channels')
  Future<ChannelDto> create4(
    @Path('appId') String appId,
    @Body() CreateChannelRequestDto createChannelRequestDto,
  );
}
