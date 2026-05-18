import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/channels/channel_dto.dart';
import 'package:dashpod_api/src/models/channels/create_channel_request_dto.dart';

part 'channels_api.g.dart';

/// Endpoints with tag channels-controller
@RestApi()
abstract class ChannelsApi {
  factory ChannelsApi(Dio dio) => _ChannelsApi(dio);

  @GET('/api/v1/apps/{appId}/channels')
  Future<List<ChannelDto>> listChannels(@Path('appId') String appId);

  @POST('/api/v1/apps/{appId}/channels')
  Future<ChannelDto> createChannel(
    @Path('appId') String appId,
    @Body() CreateChannelRequestDto createChannelRequestDto,
  );
}
