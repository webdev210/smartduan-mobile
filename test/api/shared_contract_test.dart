import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/projects.dart';
import 'package:smartduan/api/units.dart';
import 'package:smartduan/api/sales.dart';
import 'package:smartduan/api/content.dart';
import 'package:smartduan/auth/token_store.dart';

import '../auth/token_store_test.dart' show MemoryStorage;
import 'fake_http.dart';

typedef Contract = ({
  String path,
  String method,
  Map<String, dynamic> params,
  Object? body,
  Future<Object?> Function() call,
});

void main() {
  late FakeHttp http;
  late ApiClient client;
  late ProjectsApi projects;
  late UnitsApi units;
  late SalesApi sales;
  late ContentApi content;
  setUp(() {
    http = FakeHttp(
      (c) => Reply(200, {
        'id': 'x',
        'code': 'X',
        'name': 'Name',
        'title': 'Title',
        'slug': 'slug',
        'block': {'id': 'b'},
        'data': c.path.endsWith('/policies/current')
            ? null
            : c.path == '/sales/announcements/a'
            ? {'id': 'a', 'title': 'Title'}
            : <Object?>[],
        'total': 0,
        'download_url': '/api/v1/public/dl/t',
        'roles': <Object?>[],
        'ok': true,
      }),
    );
    client = ApiClient(
      adapter: http,
      tokens: SecureValue('contract', storage: MemoryStorage()),
    );
    projects = ProjectsApi(client);
    units = UnitsApi(client);
    sales = SalesApi(client);
    content = ContentApi(client);
  });
  tearDown(() => client.close());

  Contract get(
    String path,
    Future<Object?> Function() call, [
    Map<String, dynamic> params = const {},
  ]) => (path: path, method: 'GET', params: params, body: null, call: call);
  Contract write(
    String path,
    String method,
    Object? body,
    Future<Object?> Function() call,
  ) => (path: path, method: method, params: const {}, body: body, call: call);
  // Literal paths/parameters copied from the four TS sources, independent of implementation.
  final cases = <String, Contract Function()>{
    'all projects': () => get('/projects', projects.fetchAllProjects, {
      'per_page': 100,
      'page': 1,
    }),
    'project': () => get('/projects/p', () => projects.fetchProject('p')),
    'blocks': () => get('/projects/p/blocks', () => projects.fetchBlocks('p')),
    'contacts': () =>
        get('/projects/p/contacts', () => projects.fetchContacts('p')),
    'plans': () => get(
      '/projects/p/plans',
      () => projects.fetchPlans('p', {'block_id': 'b', 'row_code': 'r'}),
      {'block_id': 'b', 'row_code': 'r'},
    ),
    'pins': () => get('/plans/pl/pins', () => projects.fetchPins('pl')),
    'top': () => get(
      '/projects/p/units/top',
      () => projects.fetchTopUnits('p', {
        'mode': 'corner',
        'unit_type': '2PN',
        'bedrooms': 2,
        'n': 3,
      }),
      {'mode': 'corner', 'unit_type': '2PN', 'bedrooms': 2, 'n': 3},
    ),
    'subdivisions': () =>
        get('/projects/p/subdivisions', () => projects.fetchSubdivisions('p')),
    'share links': () =>
        get('/projects/p/share-links', () => projects.fetchShareLinks('p')),
    'create share': () => write(
      '/projects/p/share-links',
      'POST',
      {},
      () => projects.createShareLink('p'),
    ),
    'create block share': () => write('/projects/p/share-links', 'POST', {
      'block_id': 'b',
    }, () => projects.createShareLink('p', 'b')),
    'revoke share': () => write(
      '/share-links/l',
      'DELETE',
      null,
      () => projects.revokeShareLink('l'),
    ),
    'presentation board': () => get(
      '/projects/p/presentation-board',
      () => projects.fetchPresentationBoard('p'),
    ),
    'presentation stack': () => get(
      '/projects/p/presentation-board/blocks/b/stack-plan',
      () => projects.fetchPresentationStack('p', 'b'),
    ),
    'presentation unit': () => get(
      '/projects/p/presentation-board/units/u/detail',
      () => projects.fetchPresentationUnit('p', 'u'),
    ),
    'all units': () => get(
      '/projects/p/units',
      () => units.fetchAllUnits('p', {'block_id': 'b', 'status': 'available'}),
      {'block_id': 'b', 'status': 'available', 'per_page': 200, 'page': 1},
    ),
    'stack': () => get('/blocks/b/stack-plan', () => units.fetchStackPlan('b')),
    'floors': () => get('/blocks/b/floors', () => units.fetchFloors('b')),
    'unit detail': () =>
        get('/units/u/detail', () => units.fetchUnitDetail('u')),
    'images': () => get('/units/u/images', () => units.fetchUnitImages('u')),
    'unit history': () => get(
      '/units/u/history',
      () => units.fetchUnitHistory('u'),
      {'per_page': 50},
    ),
    'enums': () => get('/inventory/enums', units.fetchEnums),
    'project history': () => get(
      '/projects/p/units/history',
      () => units.fetchProjectHistory('p', 2),
      {'per_page': 100, 'page': 2},
    ),
    'search': () => get(
      '/sales/units/search',
      () => sales.searchUnits({
        'q': 'A',
        'price_min': 1,
        'sort': 'price_list:asc',
      }),
      {'q': 'A', 'price_min': 1, 'sort': 'price_list:asc'},
    ),
    'saved': () => get('/sales/units/search/saved', sales.fetchSavedFilters),
    'save': () => write('/sales/units/search/saved', 'POST', {
      'name': 'Name',
      'params': {'q': 'A'},
    }, () => sales.saveFilter('Name', {'q': 'A'})),
    'delete saved': () => write(
      '/sales/units/search/saved/f',
      'DELETE',
      null,
      () => sales.deleteSavedFilter('f'),
    ),
    'available': () => get('/sales/units/search', sales.countAvailable, {
      'status': 'available',
      'per_page': 1,
    }),
    'compare': () => get('/sales/me/compare', sales.fetchCompare),
    'add compare': () => write('/sales/me/compare', 'POST', {
      'unit_id': 'u',
    }, () => sales.addCompare('u')),
    'remove compare encodes id': () => write(
      '/sales/me/compare/a%2Fb%20c',
      'DELETE',
      null,
      () => sales.removeCompare('a/b c'),
    ),
    'listing': () => write('/sales/listings/generate', 'POST', {
      'unit_id': 'u',
      'channel': 'zalo',
    }, () => sales.generateListing('u', 'zalo')),
    'loan': () => write('/sales/loans/calculate', 'POST', {
      'project_id': 'p',
      'price': 12,
    }, () => sales.calculateLoan({'project_id': 'p', 'price': 12})),
    'declare': () => write(
      '/sales/bookings/declare',
      'POST',
      {'unit_id': 'u', 'customer_name': 'Name', 'customer_phone': '0901'},
      () => sales.declareBooking({
        'unit_id': 'u',
        'customer_name': 'Name',
        'customer_phone': '0901',
      }),
    ),
    'my bookings': () => get(
      '/sales/bookings/mine',
      () => sales.fetchMyBookings(2),
      {'page': 2},
    ),
    'review': () => get('/bookings', sales.fetchBookingsToReview, {
      'status': 'declared,synced',
    }),
    'decide': () => write('/bookings/b', 'PATCH', {
      'status': 'rejected',
      'reason': 'reason',
    }, () => sales.decideBooking('b', 'rejected', 'reason')),
    'decide without reason': () => write('/bookings/b', 'PATCH', {
      'status': 'confirmed',
    }, () => sales.decideBooking('b', 'confirmed')),
    'team': () => get('/sales/team', sales.fetchTeam),
    'become sales': () => write('/sales/become-sales', 'POST', {
      'branch_code': 'HN',
    }, () => sales.becomeSales({'branch_code': 'HN'})),
    'managers': () => get('/sales/managers', sales.fetchManagers),
    'f2': () => write(
      '/sales/request-f2',
      'POST',
      {'manager_id': 'm', 'full_name': 'Name', 'address': 'HN'},
      () => sales.requestF2({
        'manager_id': 'm',
        'full_name': 'Name',
        'address': 'HN',
      }),
    ),
    'notifications': () =>
        get('/sales/notifications', sales.fetchNotifications),
    'read all': () => write(
      '/sales/notifications/read',
      'POST',
      {},
      sales.markNotificationsRead,
    ),
    'read selected': () => write('/sales/notifications/read', 'POST', {
      'ids': ['n'],
    }, () => sales.markNotificationsRead(['n'])),
    'read empty selected': () => write('/sales/notifications/read', 'POST', {
      'ids': <Object?>[],
    }, () => sales.markNotificationsRead([])),
    'announcements': () => get(
      '/sales/announcements',
      () => sales.fetchAnnouncements(2),
      {'page': 2},
    ),
    'announcement': () =>
        get('/sales/announcements/a', () => sales.fetchAnnouncement('a')),
    'consult': () => write(
      '/sales/consult',
      'POST',
      {'consent': true, 'project_id': 'p', 'message': 'hi'},
      () => sales.submitConsult({
        'consent': true,
        'project_id': 'p',
        'message': 'hi',
      }),
    ),
    'process pages': () => get('/process-pages', sales.fetchProcessPages),
    'process page': () =>
        get('/process-pages/slug', () => sales.fetchProcessPage('slug')),
    'process access': () => write(
      '/process-pages/slug/request',
      'POST',
      null,
      () => sales.requestProcessAccess('slug'),
    ),
    'activity': () => write(
      '/activity',
      'POST',
      {'kind': 'project', 'project_id': 'p', 'path': '/du-an/p'},
      () => sales.logActivity({
        'kind': 'project',
        'project_id': 'p',
        'path': '/du-an/p',
      }),
    ),
    'branches': () => get('/branches', sales.fetchBranches),
    'current': () => get(
      '/content/projects/p/policies/current',
      () => content.fetchCurrentPolicy('p'),
    ),
    'current fund': () => get(
      '/content/projects/p/policies/current',
      () => content.fetchCurrentPolicy('p', 'f'),
      {'fund': 'f'},
    ),
    'scopes': () => get(
      '/content/projects/p/policies/current-scopes',
      () => content.fetchPolicyScopes('p'),
    ),
    'policy history': () => get(
      '/content/projects/p/policies/history',
      () => content.fetchPolicyHistory('p'),
    ),
    'documents': () =>
        get('/content/projects/p/documents', () => content.fetchDocuments('p')),
    'media': () =>
        get('/content/projects/p/media', () => content.fetchMedia('p')),
    'media type': () => get(
      '/content/projects/p/media',
      () => content.fetchMedia('p', 'tour360'),
      {'media_type': 'tour360'},
    ),
    'progress': () =>
        get('/content/projects/p/progress', () => content.fetchProgress('p')),
    'faqs': () => get('/content/projects/p/faqs', () => content.fetchFaqs('p')),
    'download link': () => write(
      '/content/documents/d/download-link',
      'POST',
      null,
      () => content.documentDownloadUrl('d'),
    ),
  };
  for (final entry in cases.entries) {
    test('contract ${entry.key}', () async {
      final c = entry.value();
      await c.call();
      expect(http.seen, hasLength(1));
      final request = http.seen.single;
      expect(request.path, c.path);
      expect(request.method, c.method);
      expect(request.queryParameters, c.params);
      expect(request.data, c.body);
    });
  }
  for (final kind in ['projects', 'units']) {
    test('$kind follows total despite mobile clamp', () async {
      http.respond = (c) {
        final page = c.queryParameters['page'] as int;
        return Reply(200, {
          'data': List.generate(
            page == 3 ? 1 : 50,
            (i) => {'id': '$page-$i', 'code': 'X', 'name': 'Name'},
          ),
          'total': 101,
          'per_page': 50,
        });
      };
      final result = kind == 'projects'
          ? await projects.fetchAllProjects()
          : await units.fetchAllUnits('p');
      expect(result, hasLength(101));
      expect(http.seen.map((c) => c.queryParameters['page']), [1, 2, 3]);
    });
    test('$kind empty page terminates inconsistent total', () async {
      http.respond = (_) =>
          const Reply(200, {'data': <Object?>[], 'total': 999});
      expect(
        kind == 'projects'
            ? await projects.fetchAllProjects()
            : await units.fetchAllUnits('p'),
        isEmpty,
      );
      expect(http.seen, hasLength(1));
    });
  }
  test('beacons swallow errors, consult never retries and preserves unknown delivery', () async {
    http.respond = (_) => const Reply(503, {
      'error': 'lead_delivery_unknown',
      'message': 'Unknown',
    });
    await sales.logActivity({'kind': 'page'});
    final error = await caught(sales.submitConsult({'consent': true}));
    expect(error.code, 'lead_delivery_unknown');
    expect(http.seen, hasLength(2));
  });
  test('consult requires explicit consent before request', () async {
    await expectLater(sales.submitConsult({}), throwsArgumentError);
    expect(http.seen, isEmpty);
  });

  test('export streams exact bytes into temp, sanitizes code, carries client Bearer', () async {
    final dir = await Directory.systemTemp.createTemp('step-s-');
    addTearDown(() => dir.delete(recursive: true));
    await client.tokens.set('test-bearer');
    final adapter = ExportHttp(200);
    final path = await UnitsApi(
      client,
      downloadAdapter: adapter,
      temporaryDirectory: () async => dir,
    ).downloadUnitsXlsx('p', 'A / Đ');
    expect(await File(path).readAsBytes(), [80, 75, 0, 255, 10]);
    expect(File(path).uri.pathSegments.last, 'bang-hang-A____.xlsx');
    expect(adapter.seen!.path, '/projects/p/units/export.xlsx');
    expect(adapter.seen!.headers['Authorization'], 'Bearer test-bearer');
    expect(adapter.seen!.followRedirects, isFalse);
    expect(await File('$path.part').exists(), isFalse);
  });
  test('export 403 surfaces API error and removes partial file', () async {
    final dir = await Directory.systemTemp.createTemp('step-s-');
    addTearDown(() => dir.delete(recursive: true));
    final error = await caught(
      UnitsApi(
        client,
        downloadAdapter: ExportHttp(403),
        temporaryDirectory: () async => dir,
      ).downloadUnitsXlsx('p', 'P'),
    );
    expect(error.status, 403);
    expect(await dir.list().toList(), isEmpty);
  });
}

class ExportHttp implements HttpClientAdapter {
  ExportHttp(this.status);
  final int status;
  RequestOptions? seen;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    return ResponseBody(
      Stream.fromIterable([
        Uint8List.fromList([80, 75]),
        Uint8List.fromList([0, 255, 10]),
      ]),
      status,
    );
  }

  @override
  void close({bool force = false}) {}
}
