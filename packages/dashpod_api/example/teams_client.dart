import 'package:dio/dio.dart';
import 'package:fractal_effect/data/team/dto/create_team_dto.dart';
import 'package:fractal_effect/data/team/dto/delete_team_dto.dart';
import 'package:fractal_effect/data/team/dto/edit_team_dto.dart';
import 'package:fractal_effect/entity/team/team.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

part 'teams_client.g.dart';

// TODO(netos23): remove after geteway fixed
@RestApi(baseUrl: 'http://localhost:8080')
@singleton
abstract class TeamsClient {
  @factoryMethod
  factory TeamsClient(Dio dio) => _TeamsClient(dio);

  @GET('/team/')
  Future<List<Team>> getTeams();

  @POST('/team/')
  Future<Team> createTeam(@Body() CreateTeamDto team);

  @PUT('/team/')
  Future<Team> editTeam(@Body() EditTeamDto team);

  @DELETE('/team/')
  Future<Team> deleteTeam(@Body() DeleteTeamDto team);

  @GET('/team/{teamId}')
  Future<DetailedTeam> getTeam(@Path() int teamId);
}
