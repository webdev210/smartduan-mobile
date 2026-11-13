import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/auth.dart' show basketUrl;
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/projects.dart';
import 'package:smartduan/api/sales.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

void main() {
  test('basket URL strips old query, trailing slash and ticket in hash', () {
    expect(
      basketUrl(
        'https://ro.example.com/du-an/abc?old=1#x',
        't.o+k',
        parent: 'https://smartduan.vn/sales',
        nonce: 'n1',
      ),
      'https://ro.example.com/du-an/abc/?embed=1&parent=https%3A%2F%2Fsmartduan.vn&nonce=n1#sd_token=t.o%2Bk',
    );
  });
  test('basket origin and existing slash are not doubled', () {
    expect(
      basketUrl(
        'https://ro.example.com',
        't',
        parent: 'https://smartduan.vn',
        nonce: 'n',
      ),
      startsWith('https://ro.example.com/?embed=1'),
    );
    expect(
      basketUrl(
        'https://ro.example.com/a/',
        't',
        parent: 'https://smartduan.vn',
        nonce: 'n',
      ),
      startsWith('https://ro.example.com/a/?embed=1'),
    );
  });
  test('share URL joins web base and url_path, trims slash', () {
    expect(
      shareUrl(
        const ShareLink(id: 'l', urlPath: '/s/abc'),
        'https://smartduan.vn/',
      ),
      'https://smartduan.vn/s/abc',
    );
  });
  test(
    'share create empty body and revoke path (same partial RN fixture)',
    () async {
      final http = FakeHttp(
        (r) => r.method == 'POST'
            ? const Reply(201, {'id': 'l1', 'url_path': '/s/x'})
            : const Reply(204),
      );
      final client = ApiClient(
        adapter: http,
        tokens: SecureValue('tools', storage: MemoryStorage()),
      );
      addTearDown(client.close);
      await ProjectsApi(client).createShareLink('p1');
      await ProjectsApi(client).revokeShareLink('l1');
      expect(
        (http.seen[0].method, http.seen[0].path),
        ('POST', '/projects/p1/share-links'),
      );
      expect(http.seen[0].data, isEmpty);
      expect(
        (http.seen[1].method, http.seen[1].path),
        ('DELETE', '/share-links/l1'),
      );
    },
  );
  test('free sales share receives 403 API error', () async {
    final client = ApiClient(
      adapter: FakeHttp(
        (_) => const Reply(403, {
          'error': 'forbidden',
          'message': 'Không có quyền',
        }),
      ),
      tokens: SecureValue('tools', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    expect(
      (await caught(ProjectsApi(client).createShareLink('p1'))).status,
      403,
    );
  });
  test('top units passes mode query with same sparse fixture', () async {
    final http = FakeHttp((_) => const Reply(200, {'groups': <Object?>[]}));
    final client = ApiClient(
      adapter: http,
      tokens: SecureValue('tools', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    await ProjectsApi(client).fetchTopUnits('p1', {'mode': 'corner'});
    expect(http.seen.single.path, '/projects/p1/units/top');
    expect(http.seen.single.queryParameters, {'mode': 'corner'});
  });
  test('process cooldown preserves backend sentence', () async {
    final client = ApiClient(
      adapter: FakeHttp(
        (_) => const Reply(429, {
          'error': 'cooldown',
          'message': 'Bạn có thể xin lại sau 24 giờ kể từ khi bị từ chối.',
        }),
      ),
      tokens: SecureValue('tools', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    final e = await caught(
      SalesApi(client).requestProcessAccess('quy-trinh-a'),
    );
    expect(
      (e.status, e.code, e.message),
      (429, 'cooldown', 'Bạn có thể xin lại sau 24 giờ kể từ khi bị từ chối.'),
    );
  });
  test('views aggregate per project, most viewed first', () {
    ProjectViewRow row(String id, int views, [int cta = 0]) => ProjectViewRow(
      projectId: id,
      project: id,
      day: '2026-11-01',
      viewerType: 'guest',
      views: views,
      ctaClicks: cta,
    );
    expect(sumViewsByProject([row('a', 2, 1), row('b', 5), row('a', 4, 2)]), [
      (project: 'a', views: 6, ctaClicks: 3, leads: 0),
      (project: 'b', views: 5, ctaClicks: 0, leads: 0),
    ]);
  });
  test(
    'loan policy labels match default, manual, common, fund and overrides',
    () {
      LoanResult r(
        String source, {
        String? fund,
        List<String> overrides = const [],
      }) => LoanResult.fromJson({
        'terms_source': source,
        'fund': fund,
        'overrides': overrides,
      });
      expect(loanTermsLabel(r('default')), 'Mặc định của sàn');
      expect(loanTermsLabel(r('manual')), 'Tự nhập — không theo CSBH');
      expect(loanTermsLabel(r('policy')), 'Theo CSBH chung');
      expect(loanTermsLabel(r('policy', fund: 'F1')), 'Theo CSBH quỹ F1');
      expect(
        loanTermsLabel(
          r(
            'mixed',
            overrides: ['floating_rate', 'supported_rate', 'grace_months'],
          ),
        ),
        'Theo CSBH chung, có điều chỉnh: lãi thả nổi, lãi ưu đãi, tháng ưu đãi',
      );
    },
  );
}
