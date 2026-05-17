import 'package:dashpod_api/api.dart';

class Dashpod {
  Dashpod({ApiClient? client}) : client = client ?? ApiClient();

  final ApiClient client;

  ApiKeysControllerApi get apiKeysController => ApiKeysControllerApi(client);
  AppCollaboratorsControllerApi get appCollaboratorsController =>
      AppCollaboratorsControllerApi(client);
  AppsControllerApi get appsController => AppsControllerApi(client);
  ChannelsControllerApi get channelsController => ChannelsControllerApi(client);
  PatchCheckControllerApi get patchCheckController =>
      PatchCheckControllerApi(client);
  PatchEventsControllerApi get patchEventsController =>
      PatchEventsControllerApi(client);
  PatchesControllerApi get patchesController => PatchesControllerApi(client);
  ReleasePatchesControllerApi get releasePatchesController =>
      ReleasePatchesControllerApi(client);
  ReleasesControllerApi get releasesController => ReleasesControllerApi(client);
  UsersControllerApi get usersController => UsersControllerApi(client);
}
