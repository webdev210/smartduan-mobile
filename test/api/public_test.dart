import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/public.dart';

import 'fake_http.dart';

Map<String, Object?> projectJson(String id) => {
  'id': id,
  'name': 'Dự án $id',
  'code': id,
  'project_type': null,
  'developer': null,
  'province': null,
  'district': null,
  'ward': null,
  'address': null,
  'price_from': null,
  'status': 'selling',
  'overview_json': null,
  'documents': [],
  'cover_url': null,
  'has_tour360': false,
  'activity_7d': 0,
};

void main() {
  test('RN fixture follows two 200-row pages until total 201', () async {
    final http = FakeHttp((c) {
      final page = c.queryParameters['page'] as int;
      return Reply(200, {
        'data': List.generate(
          page == 1 ? 200 : 1,
          (i) => projectJson('p${(page - 1) * 200 + i}'),
        ),
        'page': page,
        'per_page': 200,
        'total': 201,
      });
    });
    final client = ApiClient(adapter: http);
    addTearDown(client.close);
    expect(await PublicApi(client).listAllPublicProjects(), hasLength(201));
    expect(
      http.seen.map(
        (c) => (
          c.path,
          c.queryParameters['page'],
          c.queryParameters['per_page'],
          c.queryParameters['sort'],
        ),
      ),
      [
        ('/public/projects', 1, 200, 'hot'),
        ('/public/projects', 2, 200, 'hot'),
      ],
    );
  });
  test('all pages follow total even with a mobile per_page clamp', () async {
    final http = FakeHttp((c) {
      final page = c.queryParameters['page'] as int;
      return Reply(200, {
        'data': List.generate(
          page == 5 ? 1 : 50,
          (i) => projectJson('p${(page - 1) * 50 + i}'),
        ),
        'page': page,
        'per_page': 50,
        'total': 201,
      });
    });
    final client = ApiClient(adapter: http);
    addTearDown(client.close);
    final all = await PublicApi(client).listAllPublicProjects();
    expect(all.length, 201);
    expect(http.seen.map((c) => c.queryParameters['page']), [1, 2, 3, 4, 5]);
    expect(
      http.seen.every(
        (c) =>
            c.queryParameters['sort'] == 'hot' &&
            c.queryParameters['per_page'] == 200,
      ),
      true,
    );
  });
  test('empty page stops an inconsistent total', () async {
    final http = FakeHttp(
      (_) => const Reply(200, {
        'data': <Object?>[],
        'page': 1,
        'per_page': 200,
        'total': 999,
      }),
    );
    final client = ApiClient(adapter: http);
    addTearDown(client.close);
    expect(await PublicApi(client).listAllPublicProjects(), isEmpty);
    expect(http.seen.length, 1);
  });
  test('CTA beacon swallows errors and never retries', () async {
    final http = FakeHttp((_) => const Reply(500));
    final client = ApiClient(adapter: http);
    addTearDown(client.close);
    await PublicApi(client).trackCtaClick('p1');
    expect(http.seen.length, 1);
  });
}
