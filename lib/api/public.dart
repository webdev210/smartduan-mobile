import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../config.dart';
import 'client.dart';
import 'models.dart';

export 'models.dart';

class PublicFilters {
  const PublicFilters({
    this.hot,
    this.q,
    this.province,
    this.projectType,
    this.developerId,
    this.status,
    this.sort,
    this.page,
    this.perPage,
  });
  final String? hot, q, province, projectType, developerId, status, sort;
  final int? page, perPage;
  Map<String, Object> toJson() => {
    'hot': ?hot,
    'q': ?q,
    'province': ?province,
    'project_type': ?projectType,
    'developer_id': ?developerId,
    'status': ?status,
    'sort': ?sort,
    'page': ?page,
    'per_page': ?perPage,
  };
  @override
  bool operator ==(Object other) =>
      other is PublicFilters &&
      hot == other.hot &&
      q == other.q &&
      province == other.province &&
      projectType == other.projectType &&
      developerId == other.developerId &&
      status == other.status &&
      sort == other.sort &&
      page == other.page &&
      perPage == other.perPage;
  @override
  int get hashCode => Object.hash(
    hot,
    q,
    province,
    projectType,
    developerId,
    status,
    sort,
    page,
    perPage,
  );
}

class PublicLoanBody {
  const PublicLoanBody({
    required this.price,
    required this.loanRatio,
    required this.termMonths,
    this.annualRate,
    this.graceMonths,
  });
  final String price;
  final num loanRatio;
  final int termMonths;
  final num? annualRate;
  final int? graceMonths;
  Map<String, Object> toJson() => {
    'price': price,
    'loan_ratio': loanRatio,
    'term_months': termMonths,
    'annual_rate': ?annualRate,
    'grace_months': ?graceMonths,
  };
}

class PublicApi {
  PublicApi(this.client, {String? origin}) : origin = origin ?? originUrl;
  final ApiClient client;
  final String origin;
  Future<Object?> health() =>
      client.get('$origin/health').timeout(const Duration(seconds: 10));
  Future<List<Province>> fetchProvinces() async => jsonList(
    jsonObject(await client.get('/public/provinces'))['data'],
    Province.fromJson,
  );
  Future<FullPolicy> fetchFullPolicy() async => FullPolicy.fromJson(
    jsonObject(await client.get('/privacy/policy/current/full')),
  );
  Future<List<FooterLink>> listFooterLinks() async => jsonList(
    jsonObject(await client.get('/public/footer-links'))['data'],
    FooterLink.fromJson,
  );
  Future<PrivacyPolicy> fetchPrivacyPolicy() async => PrivacyPolicy.fromJson(
    jsonObject(await client.get('/privacy/policy/current')),
  );
  Future<Paged<PublicProject>> listPublicProjects([
    PublicFilters filters = const PublicFilters(),
  ]) async => Paged.fromJson(
    jsonObject(await client.get('/public/projects', filters.toJson())),
    PublicProject.fromJson,
  );
  Future<List<PublicProject>> listAllPublicProjects() async {
    final all = <PublicProject>[];
    for (var page = 1; ; page++) {
      final res = await listPublicProjects(
        PublicFilters(sort: 'hot', perPage: 200, page: page),
      );
      all.addAll(res.data);
      if (all.length >= res.total || res.data.isEmpty) {
        return List.unmodifiable(all);
      }
    }
  }

  Future<PublicProject> fetchPublicProject(String code) async =>
      PublicProject.fromJson(
        jsonObject(
          await client.get('/public/projects/${Uri.encodeComponent(code)}'),
        ),
      );
  Future<PublicStats> fetchPublicStats() async => PublicStats.fromJson(
    jsonObject(jsonObject(await client.get('/public/stats'))['data']),
  );
  Future<List<PublicPost>> listPublicPosts(
    String kind, [
    int perPage = 3,
  ]) async => Paged.fromJson(
    jsonObject(
      await client.get('/public/posts', {'kind': kind, 'per_page': perPage}),
    ),
    PublicPost.fromJson,
  ).data;
  Future<PublicPost> fetchPublicPost(String slug) async => PublicPost.fromJson(
    jsonObject(await client.get('/public/posts/${Uri.encodeComponent(slug)}')),
  );
  Future<List<PublicDeveloper>> listPublicDevelopers() async => Paged.fromJson(
    jsonObject(await client.get('/public/developers', {'per_page': 200})),
    PublicDeveloper.fromJson,
  ).data;
  Future<PublicDeveloper> fetchPublicDeveloper(String slug) async =>
      PublicDeveloper.fromJson(
        jsonObject(
          await client.get('/public/developers/${Uri.encodeComponent(slug)}'),
        ),
      );
  Future<LoanResult> calculatePublicLoan(PublicLoanBody body) async =>
      LoanResult.fromJson(
        jsonObject(await client.post('/public/loans/calculate', body.toJson())),
      );
  Future<void> trackCtaClick(String projectId) async {
    try {
      await client.post('/public/events', {
        'project_id': projectId,
        'event': 'cta_click',
      });
    } catch (_) {
      /* Best-effort beacon. */
    }
  }
}

final publicApiProvider = Provider<PublicApi>(
  (ref) => PublicApi(ref.watch(apiClientProvider)),
);
final healthProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(publicApiProvider).health(),
);
final fetchProvincesProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(publicApiProvider).fetchProvinces(),
);
final fetchFullPolicyProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(publicApiProvider).fetchFullPolicy(),
);
final listFooterLinksProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(publicApiProvider).listFooterLinks(),
);
final fetchPrivacyPolicyProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(publicApiProvider).fetchPrivacyPolicy(),
);
final listPublicProjectsProvider = FutureProvider.autoDispose
    .family<Paged<PublicProject>, PublicFilters>(
      (ref, filters) =>
          ref.watch(publicApiProvider).listPublicProjects(filters),
    );
final listAllPublicProjectsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(publicApiProvider).listAllPublicProjects(),
);
final fetchPublicProjectProvider = FutureProvider.autoDispose
    .family<PublicProject, String>(
      (ref, code) => ref.watch(publicApiProvider).fetchPublicProject(code),
    );
final fetchPublicStatsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(publicApiProvider).fetchPublicStats(),
);
final listPublicPostsProvider = FutureProvider.autoDispose
    .family<List<PublicPost>, ({String kind, int perPage})>(
      (ref, args) =>
          ref.watch(publicApiProvider).listPublicPosts(args.kind, args.perPage),
    );
final fetchPublicPostProvider = FutureProvider.autoDispose
    .family<PublicPost, String>(
      (ref, slug) => ref.watch(publicApiProvider).fetchPublicPost(slug),
    );
final listPublicDevelopersProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(publicApiProvider).listPublicDevelopers(),
);
final fetchPublicDeveloperProvider = FutureProvider.autoDispose
    .family<PublicDeveloper, String>(
      (ref, slug) => ref.watch(publicApiProvider).fetchPublicDeveloper(slug),
    );
// Mutations are called through publicApiProvider, never cached or auto-retried.
