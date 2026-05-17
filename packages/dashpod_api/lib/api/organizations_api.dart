import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/organizations/get_organization_apps_response_dto.dart';
import 'package:dashpod_api/src/models/organizations/get_organization_users_response_dto.dart';
import 'package:dashpod_api/src/models/organizations/get_organizations_response_dto.dart';

part 'organizations_api.g.dart';

/// Endpoints with tag organizations-controller
@RestApi()
abstract class OrganizationsApi {
  factory OrganizationsApi(Dio dio) => _OrganizationsApi(dio);

  @GET('/api/v1/organizations/{organizationId}/users')
  Future<GetOrganizationUsersResponseDto> listUsers(
    @Path('organizationId') int organizationId,
  );

  @GET('/api/v1/organizations/{organizationId}/apps')
  Future<GetOrganizationAppsResponseDto> listApps(
    @Path('organizationId') int organizationId,
  );

  @GET('/api/v1/organizations')
  Future<GetOrganizationsResponseDto> list5();
}
