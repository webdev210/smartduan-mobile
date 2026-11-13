import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';
import 'models_test.dart' show developerJson, postJson, loanJson;
import 'public_test.dart' show projectJson;

Map<String, Object?> page(List<Object?> rows) => {
  'data': rows,
  'page': 1,
  'per_page': 50,
  'total': rows.length,
};
void main() {
  test(
    'all public endpoints, envelopes and encoded path parameters match RN',
    () async {
      final http = FakeHttp(
        (c) => Reply(200, switch (c.path) {
          'https://example.test/m/health' => {'ok': true},
          '/public/provinces' => {
            'data': [
              {
                'name': 'TP.HCM',
                'old_names': ['Bình Dương'],
              },
            ],
          },
          '/public/footer-links' => {
            'data': [
              {
                'label': 'Căn hộ',
                'href': '/du-an?project_type=apartment',
                'count': 3,
              },
            ],
          },
          '/privacy/policy/current' => {
            'version': 'v1',
            'title': 'Chính sách',
            'url': null,
            'effective_from': '2026-11-01',
          },
          '/privacy/policy/current/full' => {
            'version': 'v1',
            'title': null,
            'effective_from': null,
            'body': '<p>Chính sách</p>',
          },
          '/public/projects' => page([projectJson('p')]),
          '/public/stats' => {
            'data': {
              'developers': 1,
              'projects_selling': 2,
              'activity_7d_total': 3,
              'contact': {'hotline': '1900', 'zalo_url': null},
            },
          },
          '/public/posts' => page([postJson]),
          '/public/developers' => page([developerJson]),
          '/public/loans/calculate' => loanJson,
          '/public/events' => {'ok': true},
          _ when c.path.startsWith('/public/projects/') => projectJson('p'),
          _ when c.path.startsWith('/public/posts/') => postJson,
          _ when c.path.startsWith('/public/developers/') => developerJson,
          _ => throw StateError('Unexpected endpoint'),
        }),
      );
      final tokens = SecureValue('test', storage: MemoryStorage());
      await tokens.set('SESSION');
      final client = ApiClient(adapter: http, tokens: tokens);
      addTearDown(client.close);
      final api = PublicApi(client, origin: 'https://example.test/m');
      expect(await api.health(), {'ok': true});
      expect(http.seen.single.headers.containsKey('Authorization'), false);
      expect((await api.fetchProvinces()).single.oldNames, ['Bình Dương']);
      expect((await api.listFooterLinks()).single.count, 3);
      expect((await api.fetchPrivacyPolicy()).effectiveFrom, '2026-11-01');
      expect((await api.fetchFullPolicy()).body, '<p>Chính sách</p>');
      const filters = PublicFilters(
        hot: '1',
        q: 'a',
        province: 'TP.HCM',
        projectType: 'mixed',
        developerId: 'd',
        status: 'selling',
        sort: 'price_asc',
        page: 2,
        perPage: 8,
      );
      expect((await api.listPublicProjects(filters)).data.single.id, 'p');
      expect(http.seen.last.queryParameters, {
        'hot': '1',
        'q': 'a',
        'province': 'TP.HCM',
        'project_type': 'mixed',
        'developer_id': 'd',
        'status': 'selling',
        'sort': 'price_asc',
        'page': 2,
        'per_page': 8,
      });
      const key = 'A/B ?#';
      await api.fetchPublicProject(key);
      expect(
        http.seen.last.path,
        '/public/projects/${Uri.encodeComponent(key)}',
      );
      expect((await api.fetchPublicStats()).contact.hotline, '1900');
      expect((await api.listPublicPosts('event')).single.slug, 'tin-moi');
      expect(http.seen.last.queryParameters, {'kind': 'event', 'per_page': 3});
      await api.listPublicPosts('guide', 6);
      expect(http.seen.last.queryParameters, {'kind': 'guide', 'per_page': 6});
      await api.fetchPublicPost(key);
      expect(http.seen.last.path, '/public/posts/${Uri.encodeComponent(key)}');
      expect((await api.listPublicDevelopers()).single.name, 'Sun Group');
      expect(http.seen.last.queryParameters, {'per_page': 200});
      await api.fetchPublicDeveloper(key);
      expect(
        http.seen.last.path,
        '/public/developers/${Uri.encodeComponent(key)}',
      );
      await api.calculatePublicLoan(
        const PublicLoanBody(
          price: '1000000000',
          loanRatio: 0.7,
          termMonths: 120,
        ),
      );
      expect(http.seen.last.data, {
        'price': '1000000000',
        'loan_ratio': 0.7,
        'term_months': 120,
      });
      await api.calculatePublicLoan(
        const PublicLoanBody(
          price: '100',
          loanRatio: 0.5,
          termMonths: 12,
          annualRate: 10,
          graceMonths: 2,
        ),
      );
      expect(http.seen.last.data, {
        'price': '100',
        'loan_ratio': 0.5,
        'term_months': 12,
        'annual_rate': 10,
        'grace_months': 2,
      });
      await api.trackCtaClick('p');
      expect(http.seen.last.method, 'POST');
      expect(http.seen.last.data, {'project_id': 'p', 'event': 'cta_click'});
      expect(
        http.seen
            .where((c) => c.path.startsWith('/public/'))
            .every((c) => !c.headers.containsKey('Authorization')),
        true,
      );
    },
  );
  test(
    'public read providers use injected client and stable filter family keys',
    () async {
      final http = FakeHttp((_) => Reply(200, page([projectJson('p')])));
      final client = ApiClient(adapter: http);
      addTearDown(client.close);
      final container = ProviderContainer.test(
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      const filter = PublicFilters(sort: 'hot');
      final subscription = container.listen(
        listPublicProjectsProvider(filter),
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(
        (await container.read(listPublicProjectsProvider(filter).future)).total,
        1,
      );
      expect(
        (await container.read(
          listPublicProjectsProvider(const PublicFilters(sort: 'hot')).future,
        )).data.single.code,
        'p',
      );
      expect(http.seen.length, 1);
      expect(const PublicFilters().toJson(), isEmpty);
    },
  );
  test('loan mutation errors propagate after one attempt', () async {
    final http = FakeHttp((_) => const Reply(500));
    final client = ApiClient(adapter: http);
    addTearDown(client.close);
    await caught(
      PublicApi(client).calculatePublicLoan(
        const PublicLoanBody(price: '100', loanRatio: 0.5, termMonths: 12),
      ),
    );
    expect(http.seen.length, 1);
  });
}
