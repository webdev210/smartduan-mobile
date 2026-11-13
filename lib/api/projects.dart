import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;

import '../auth/session.dart';
import '../config.dart';
import 'client.dart';
import 'errors.dart';
import 'models.dart';

export 'models.dart';

const perPageMax = 200;

class ProjectsApi {
  const ProjectsApi(this.client);
  final ApiClient client;

  Future<List<Project>> fetchAllProjects() async {
    final all = <Project>[];
    for (var page = 1; ; page++) {
      final result = Paged.fromJson(
        jsonObject(
          await client.get('/projects', {'per_page': 100, 'page': page}),
        ),
        Project.fromJson,
      );
      all.addAll(result.data);
      if (all.length >= result.total || result.data.isEmpty) return all;
    }
  }

  Future<Project> fetchProject(String id) async =>
      Project.fromJson(jsonObject(await client.get('/projects/$id')));
  Future<List<Block>> fetchBlocks(String projectId) async => jsonList(
    jsonObject(await client.get('/projects/$projectId/blocks'))['data'] ??
        const [],
    Block.fromJson,
  );
  Future<List<Contact>> fetchContacts(String projectId) async => jsonList(
    jsonObject(await client.get('/projects/$projectId/contacts'))['data'] ??
        const [],
    Contact.fromJson,
  );
  Future<List<Plan>> fetchPlans(
    String projectId, [
    Map<String, dynamic> params = const {},
  ]) async => jsonList(
    jsonObject(
          await client.get('/projects/$projectId/plans', params),
        )['data'] ??
        const [],
    Plan.fromJson,
  );
  Future<List<Pin>> fetchPins(String planId) async => jsonList(
    jsonObject(await client.get('/plans/$planId/pins'))['data'] ?? const [],
    Pin.fromJson,
  );
  Future<TopUnits> fetchTopUnits(
    String projectId, [
    Map<String, dynamic> params = const {},
  ]) async => TopUnits.fromJson(
    jsonObject(await client.get('/projects/$projectId/units/top', params)),
  );
  Future<List<Subdivision>> fetchSubdivisions(String projectId) async =>
      jsonList(
        jsonObject(
              await client.get('/projects/$projectId/subdivisions'),
            )['data'] ??
            const [],
        Subdivision.fromJson,
      );
  Future<List<ShareLink>> fetchShareLinks(String projectId) async => jsonList(
    jsonObject(await client.get('/projects/$projectId/share-links'))['data'] ??
        const [],
    ShareLink.fromJson,
  );
  Future<ShareLink> createShareLink(
    String projectId, [
    String? blockId,
  ]) async => ShareLink.fromJson(
    jsonObject(
      await client.post('/projects/$projectId/share-links', {
        if (blockId != null && blockId.isNotEmpty) 'block_id': blockId,
      }),
    ),
  );
  Future<void> revokeShareLink(String id) async {
    await client.del('/share-links/$id');
  }

  Future<PresentationBoard> fetchPresentationBoard(String projectId) async =>
      PresentationBoard.fromJson(
        jsonObject(await client.get('/projects/$projectId/presentation-board')),
      );
  Future<StackPlan> fetchPresentationStack(
    String projectId,
    String blockId,
  ) async => StackPlan.fromJson(
    jsonObject(
      await client.get(
        '/projects/$projectId/presentation-board/blocks/$blockId/stack-plan',
      ),
    ),
  );
  Future<Unit> fetchPresentationUnit(String projectId, String unitId) async =>
      Unit.fromJson(
        jsonObject(
          await client.get(
            '/projects/$projectId/presentation-board/units/$unitId/detail',
          ),
        ),
      );
}

String shareUrl(ShareLink link, [String base = webUrl]) =>
    '${base.replaceFirst(RegExp(r'/$'), '')}${link.urlPath}';

/// Shared guard also makes every signed-in query depend on the session snapshot.
ApiClient signedInClient(Ref ref) {
  final session = ref.watch(sessionProvider);
  if (session.status != SessionStatus.signedIn) {
    throw const ApiError(
      401,
      'unauthorized',
      'Phiên đã hết hạn, vui lòng đăng nhập lại',
    );
  }
  return ref.watch(apiClientProvider);
}

/// Clears the previous account's AsyncValue before a session-triggered reload.
/// Ordinary refreshes can still retain their previous data, as in RN Query.
class SessionQuery<T> extends AsyncNotifier<T> {
  SessionQuery(this.load);
  final Future<T> Function(Ref) load;
  Object? _session;
  @override
  Future<T> build() {
    final session = ref.watch(sessionProvider);
    if (_session != null && !identical(_session, session)) {
      // ponytail: Riverpod 3.5 preserves previous values on errors; replace this
      // with a public hard-reset API when Riverpod exposes one.
      // A loading+error state has no previous data and bypasses the merge.
      // ignore: invalid_use_of_internal_member
      state = AsyncLoading<T>().copyWithPrevious(
        AsyncError<T>(
          const ApiError(401, 'session_changed', 'Phiên đăng nhập đã thay đổi'),
          StackTrace.current,
        ),
        isRefresh: false,
      );
    }
    _session = session;
    return load(ref);
  }
}

AsyncNotifierProvider<SessionQuery<T>, T> sessionQuery<T>(
  Future<T> Function(Ref) load,
) => AsyncNotifierProvider.autoDispose<SessionQuery<T>, T>(
  () => SessionQuery(load),
);

AsyncNotifierProviderFamily<SessionQuery<T>, T, A> sessionQueryFamily<T, A>(
  Future<T> Function(Ref, A) load,
) => AsyncNotifierProvider.autoDispose.family<SessionQuery<T>, T, A>(
  (arg) => SessionQuery((ref) => load(ref, arg)),
);

final projectsApiProvider = Provider.autoDispose(
  (ref) => ProjectsApi(signedInClient(ref)),
);
final fetchAllProjectsProvider = sessionQuery(
  (ref) => ref.watch(projectsApiProvider).fetchAllProjects(),
);
final fetchProjectProvider = sessionQueryFamily<Project, String>(
  (ref, id) => ref.watch(projectsApiProvider).fetchProject(id),
);
final fetchBlocksProvider = sessionQueryFamily<List<Block>, String>(
  (ref, id) => ref.watch(projectsApiProvider).fetchBlocks(id),
);
final fetchContactsProvider = sessionQueryFamily<List<Contact>, String>(
  (ref, id) => ref.watch(projectsApiProvider).fetchContacts(id),
);
final fetchPlansProvider =
    sessionQueryFamily<List<Plan>, ({String projectId, ApiParams params})>(
      (ref, a) => ref
          .watch(projectsApiProvider)
          .fetchPlans(a.projectId, a.params.values),
    );
final fetchPinsProvider = sessionQueryFamily<List<Pin>, String>(
  (ref, id) => ref.watch(projectsApiProvider).fetchPins(id),
);
final fetchTopUnitsProvider =
    sessionQueryFamily<TopUnits, ({String projectId, ApiParams params})>(
      (ref, a) => ref
          .watch(projectsApiProvider)
          .fetchTopUnits(a.projectId, a.params.values),
    );
final fetchSubdivisionsProvider = sessionQueryFamily<List<Subdivision>, String>(
  (ref, id) => ref.watch(projectsApiProvider).fetchSubdivisions(id),
);
final fetchShareLinksProvider = sessionQueryFamily<List<ShareLink>, String>(
  (ref, id) => ref.watch(projectsApiProvider).fetchShareLinks(id),
);
final fetchPresentationBoardProvider =
    sessionQueryFamily<PresentationBoard, String>(
      (ref, id) => ref.watch(projectsApiProvider).fetchPresentationBoard(id),
    );
final fetchPresentationStackProvider =
    sessionQueryFamily<StackPlan, ({String projectId, String blockId})>(
      (ref, a) => ref
          .watch(projectsApiProvider)
          .fetchPresentationStack(a.projectId, a.blockId),
    );
final fetchPresentationUnitProvider =
    sessionQueryFamily<Unit, ({String projectId, String unitId})>(
      (ref, a) => ref
          .watch(projectsApiProvider)
          .fetchPresentationUnit(a.projectId, a.unitId),
    );
// Command providers expose callbacks: watching them never sends a write request.
final createShareLinkProvider = Provider.autoDispose(
  (ref) => ref.watch(projectsApiProvider).createShareLink,
);
final revokeShareLinkProvider = Provider.autoDispose(
  (ref) => ref.watch(projectsApiProvider).revokeShareLink,
);
