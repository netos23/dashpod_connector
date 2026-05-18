import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dashpod_api/src/models/organizations/create_organization_request_dto.dart';
import 'package:dashpod_api/src/models/organizations/get_organization_apps_response_dto.dart';
import 'package:dashpod_api/src/models/organizations/get_organization_users_response_dto.dart';
import 'package:dashpod_api/src/models/organizations/get_organizations_response_dto.dart';
import 'package:dashpod_api/src/models/organizations/invite_org_member_request_dto.dart';
import 'package:dashpod_api/src/models/organizations/org_avatar_upload_url_response_dto.dart';
import 'package:dashpod_api/src/models/organizations/organization_dto.dart';
import 'package:dashpod_api/src/models/organizations/organization_membership_dto.dart';
import 'package:dashpod_api/src/models/organizations/organization_user_dto.dart';
import 'package:dashpod_api/src/models/organizations/update_org_member_role_request_dto.dart';
import 'package:dashpod_api/src/models/organizations/update_organization_request_dto.dart';

part 'organizations_api.g.dart';

/// Endpoints with tag organizations-controller
@RestApi()
abstract class OrganizationsApi {
  factory OrganizationsApi(Dio dio) => _OrganizationsApi(dio);

  @POST('/api/v1/organizations/{organizationId}/members')
  Future<OrganizationUserDto> createMember(
    @Path('organizationId') int organizationId,
    @Body() InviteOrgMemberRequestDto inviteOrgMemberRequestDto,
  );

  @POST('/api/v1/organizations/{organizationId}/avatar')
  Future<OrgAvatarUploadUrlResponseDto> createAvatar(
    @Path('organizationId') int organizationId,
    @Query('contentLength') int contentLength,
  );

  @GET('/api/v1/organizations')
  Future<GetOrganizationsResponseDto> listOrganizations();

  @POST('/api/v1/organizations')
  Future<OrganizationMembershipDto> createOrganization(
    @Body() CreateOrganizationRequestDto createOrganizationRequestDto,
  );

  @DELETE('/api/v1/organizations/{organizationId}/members/{userId}')
  Future<dynamic> deleteMember(
    @Path('organizationId') int organizationId,
    @Path('userId') int userId,
  );

  @PATCH('/api/v1/organizations/{organizationId}/members/{userId}')
  Future<OrganizationUserDto> updateMember(
    @Path('organizationId') int organizationId,
    @Path('userId') int userId,
    @Body() UpdateOrgMemberRoleRequestDto updateOrgMemberRoleRequestDto,
  );

  @PATCH('/api/v1/organizations/{organizationId}')
  Future<OrganizationDto> updateOrganization(
    @Path('organizationId') int organizationId,
    @Body() UpdateOrganizationRequestDto updateOrganizationRequestDto,
  );

  @GET('/api/v1/organizations/{organizationId}/users')
  Future<GetOrganizationUsersResponseDto> listUsers(
    @Path('organizationId') int organizationId,
  );

  @GET('/api/v1/organizations/{organizationId}/apps')
  Future<GetOrganizationAppsResponseDto> listApps(
    @Path('organizationId') int organizationId,
  );
}
