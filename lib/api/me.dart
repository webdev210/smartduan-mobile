import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client.dart';
import 'models.dart';
import 'projects.dart' show signedInClient, sessionQuery;

export 'models.dart'
    show Profile, ProfileBranch, SalesUnitRef, Device, DownloadLog, Interests;

class MeApi {
  MeApi(this.client);
  final ApiClient client;
  Future<Profile> fetchProfile() async =>
      Profile.fromJson(jsonObject(await client.get('/sales/profile')));
  Future<List<DownloadLog>> fetchDownloads() async => jsonList(
    jsonObject(await client.get('/sales/profile/downloads'))['data'],
    DownloadLog.fromJson,
  );
  Future<List<Device>> fetchDevices() async => jsonList(
    jsonObject(await client.get('/me/devices'))['data'],
    Device.fromJson,
  );
  Future<Object?> removeDevice(String id) => client.del('/me/devices/$id');
  Future<Interests> saveInterests(Interests body) async => Interests.fromJson(
    jsonObject(await client.put('/sales/interests', body.toJson())),
  );
  Future<List<String>> fetchSavedProjects() async =>
      _codes(await client.get('/me/saved-projects'));
  Future<List<String>> saveProjects(List<String> codes) async =>
      _codes(await client.post('/me/saved-projects', {'codes': codes}));
  Future<List<String>> unsaveProject(String code) async =>
      _codes(await client.del('/me/saved-projects', {'code': code}));
  List<String> _codes(Object? reply) => jsonStrings(jsonObject(reply)['codes']);
  Future<bool> getSurveyDue() async =>
      jsonObject(jsonObject(await client.get('/sales/survey'))['data'])['due']
          as bool;
  Future<Map<String, dynamic>> submitSurvey(Map<String, Object?> body) async =>
      jsonObject(await client.post('/sales/survey', body));
}

final meApiProvider = Provider.autoDispose<MeApi>(
  (ref) => MeApi(signedInClient(ref)),
);
final fetchProfileProvider = sessionQuery(
  (ref) => ref.watch(meApiProvider).fetchProfile(),
);
final fetchDownloadsProvider = sessionQuery(
  (ref) => ref.watch(meApiProvider).fetchDownloads(),
);
final fetchDevicesProvider = sessionQuery(
  (ref) => ref.watch(meApiProvider).fetchDevices(),
);
final fetchSavedProjectsProvider = sessionQuery(
  (ref) => ref.watch(meApiProvider).fetchSavedProjects(),
);
final getSurveyDueProvider = sessionQuery(
  (ref) => ref.watch(meApiProvider).getSurveyDue(),
);
final removeDeviceProvider = Provider.autoDispose(
  (ref) => ref.watch(meApiProvider).removeDevice,
);
final saveInterestsProvider = Provider.autoDispose(
  (ref) => ref.watch(meApiProvider).saveInterests,
);
final saveProjectsProvider = Provider.autoDispose(
  (ref) => ref.watch(meApiProvider).saveProjects,
);
final unsaveProjectProvider = Provider.autoDispose(
  (ref) => ref.watch(meApiProvider).unsaveProject,
);
final submitSurveyProvider = Provider.autoDispose(
  (ref) => ref.watch(meApiProvider).submitSurvey,
);
