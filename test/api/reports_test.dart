import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/reports.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

void main() {
  late FakeHttp http;
  late ReportsApi api;
  setUp(() {
    http = FakeHttp(
      (c) => Reply(200, switch (c.path) {
        '/reports/inventory' => {
          'data': [
            {
              'project_id': 'p',
              'project': 'A',
              'counts': {'available': 2},
              'total': 2,
            },
          ],
        },
        '/reports/attention' => {
          'policies_new': {
            'count': 2,
            'projects': [
              {'id': 'p'},
            ],
          },
          'progress_changed': {'count': 1},
        },
        '/reports/recent_activity' => {
          'data': [
            {
              'unit_id': 'u',
              'unit_code': 'U',
              'project_id': 'p',
              'changed_at': '2026-11-12',
            },
          ],
        },
        '/reports/bookings_weekly' => {
          'from': '2026-10-01',
          'weeks': 8,
          'data': [
            {'week_start': '2026-11-09', 'confirmed': 2, 'declared': 3},
          ],
        },
        '/reports/inventory_updates' => {
          'data': [
            {'project_id': 'p', 'updates': 4, 'compliance_pct': 50.5},
          ],
        },
        '/reports/active_sales' => {
          'by_role': [
            {'role': 'agent', 'users': 2},
          ],
          'by_branch': [
            {'branch_id': null, 'users': 1},
          ],
        },
        '/reports/survey' => {
          'responses': 3,
          'avg_ease': 4.5,
          'ease_histogram': {'5': 2},
          'missing': [
            {'text': 'Tìm kiếm'},
          ],
        },
        '/reports/listings' => {
          'total': 5,
          'by_user': [
            {'user_id': 'u', 'count': 3},
          ],
          'by_project': [
            {'project_id': 'p', 'count': 2},
          ],
          'by_channel': {'zalo': 5},
        },
        '/reports/project_views' => {
          'data': [
            {'project_id': 'p', 'views': 9, 'leads': 1},
          ],
        },
        _ => throw StateError('Unexpected report endpoint'),
      }),
    );
    final client = ApiClient(
      adapter: http,
      tokens: SecureValue('test', storage: MemoryStorage()),
    );
    addTearDown(client.close);
    api = ReportsApi(client);
  });
  test('all nine reports use RN paths and parse nested data', () async {
    expect((await api.fetchInventoryReport()).single.counts, {'available': 2});
    final attention = await api.fetchAttention();
    expect(attention.policiesNew?.count, 2);
    expect(attention.policiesNew?.projects, [
      {'id': 'p'},
    ]);
    expect(attention.progressChanged?.count, 1);
    expect((await api.fetchRecentActivity()).single.unitCode, 'U');
    expect(http.seen.last.queryParameters, {'limit': 20});
    expect((await api.fetchBookingsWeekly()).data.single.confirmed, 2);
    expect(http.seen.last.queryParameters, {'weeks': 8});
    expect((await api.fetchInventoryUpdates()).data.single.compliancePct, 50.5);
    final active = await api.fetchActiveSales();
    expect(active.byRole.single.users, 2);
    expect(active.byBranch.single.branchId, isNull);
    final survey = await api.fetchSurveyReport();
    expect(survey.avgEase, 4.5);
    expect(survey.easeHistogram, {'5': 2});
    expect(survey.missing.single.text, 'Tìm kiếm');
    final listings = await api.fetchListingsReport();
    expect(listings.byUser.single.count, 3);
    expect(listings.byProject.single.count, 2);
    expect(listings.byChannel, {'zalo': 5});
    expect((await api.fetchProjectViews()).single.views, 9);
    expect(http.seen, hasLength(9));
    expect(http.seen.every((r) => r.method == 'GET'), true);
  });
  test('report parameters forward custom limits and weeks', () async {
    await api.fetchRecentActivity(7);
    expect(http.seen.last.queryParameters, {'limit': 7});
    await api.fetchBookingsWeekly(4);
    expect(http.seen.last.queryParameters, {'weeks': 4});
  });
  test(
    '403 is exposed so screens can hide unauthorized report blocks',
    () async {
      http.respond = (_) => const Reply(403, {'error': 'forbidden'});
      final calls = [
        api.fetchInventoryReport,
        api.fetchAttention,
        () => api.fetchRecentActivity(),
        () => api.fetchBookingsWeekly(),
        api.fetchInventoryUpdates,
        api.fetchActiveSales,
        api.fetchSurveyReport,
        api.fetchListingsReport,
        api.fetchProjectViews,
      ];
      for (final call in calls) {
        expect((await caught(call())).status, 403);
      }
    },
  );
  test(
    'sumViewsByProject reuses existing aggregation and retains first name',
    () {
      expect(
        sumViewsByProject([
          const ProjectViewRow(
            projectId: 'a',
            project: 'A',
            views: 2,
            ctaClicks: 1,
          ),
          const ProjectViewRow(projectId: 'b', project: 'B', views: 5),
          const ProjectViewRow(
            projectId: 'a',
            project: 'Renamed',
            views: 4,
            ctaClicks: 2,
            leads: 1,
          ),
        ]),
        [
          (project: 'A', views: 6, ctaClicks: 3, leads: 1),
          (project: 'B', views: 5, ctaClicks: 0, leads: 0),
        ],
      );
      expect(sumViewsByProject([]), isEmpty);
    },
  );
}
