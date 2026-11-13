import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/screens/app/notifications.dart';
import 'package:smartduan/screens/app/search_units.dart';
import 'package:smartduan/screens/app/share_links.dart';
import 'package:smartduan/screens/app/unit.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/screens/app/presentation.dart';
import 'package:smartduan/screens/app/project_history.dart';
import 'package:smartduan/screens/app/saved_projects.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import 'm5d_r4_responsive_test.dart' show mountR4, r4Reply, verticalR4;
import 'task_h_fakes.dart';

void main() {
  test('bedroom and budget predicates use existing numeric prices only', () {
    const f = UnitSearchFilters(bedrooms: '2', budget: '4');
    SearchRow row({int? bedrooms = 2, String? min, String? list}) => SearchRow(
      id: 'u',
      code: 'A',
      bedrooms: bedrooms,
      priceMin: min,
      priceList: list,
    );
    expect(f.matches(row(min: '3999999999')), isTrue);
    expect(f.matches(row(min: '4000000000')), isTrue);
    expect(f.matches(row(min: '4000000001')), isFalse);
    expect(f.matches(row(bedrooms: 1, min: '3000000000')), isFalse);
    expect(f.matches(row(bedrooms: null, min: '3000000000')), isFalse);
    expect(f.matches(row()), isFalse);
    expect(f.matches(row(min: 'invalid', list: '3500000000')), isTrue);
    expect(f.matches(row(min: 'NaN', list: '3500000000')), isTrue);
    expect(f.toParams(), {'status': 'available'});
    expect(const UnitSearchFilters(budget: '3,5').priceCeiling, 3500000000);
    for (final invalid in ['0', '-1', 'NaN', 'Infinity', 'abc', '1e308']) {
      expect(UnitSearchFilters(budget: invalid).priceCeiling, isNull);
    }
  });

  test('history sources translate known values with a readable fallback', () {
    expect(historySource('manual'), 'Cập nhật thủ công');
    expect(historySource('import'), 'Nhập dữ liệu');
    expect(historySource('sync'), 'Đồng bộ');
    expect(historySource(''), 'Chưa rõ nguồn');
    expect(historySource('external_feed'), 'Nguồn: external_feed');
  });

  for (final allowed in [true, false]) {
    testWidgets('saved board shortcut requires verified access: $allowed', (
      t,
    ) async {
      final e = HEnv(roles: allowed ? ['manager'] : []);
      e.http.respond = (r) => r4Reply(r.path);
      final router = await mountR4(t, e, const SavedProjectsScreen());
      addTearDown(router.dispose);
      expect(
        find.textContaining('Bảng hàng ·'),
        allowed ? findsOneWidget : findsNothing,
      );
      expect(
        e.http.seen.where((r) => r.path == '/projects').length,
        allowed ? 1 : 0,
      );
    });
  }

  testWidgets('history keeps changes and offers retry when code lookup fails', (
    t,
  ) async {
    final e = HEnv();
    var fail = true;
    e.http.respond = (r) => r.path == '/projects/p/units'
        ? (fail
              ? const Reply(503, {'message': 'Lỗi mã căn'})
              : const Reply(200, {
                  'data': [hUnit],
                  'total': 1,
                }))
        : r4Reply(r.path);
    final router = await mountR4(
      t,
      e,
      const ProjectHistoryScreen(projectId: 'p'),
    );
    addTearDown(router.dispose);
    expect(find.textContaining('Chưa có mã căn'), findsOneWidget);
    expect(find.textContaining('Cập nhật thủ công'), findsOneWidget);
    fail = false;
    await t.tap(find.text('Thử lại'));
    await t.pumpAndSettle();
    expect(find.textContaining('P-A101'), findsOneWidget);
  });

  testWidgets(
    'presentation system Back asks before leaving internal workspace',
    (t) async {
      final e = HEnv();
      e.http.respond = (r) => r4Reply(r.path);
      final router = await mountR4(
        t,
        e,
        const PresentationScreen(projectId: 'p'),
      );
      addTearDown(router.dispose);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Kết thúc trình chiếu?'), findsOneWidget);
      await t.tap(find.text('Tiếp tục trình chiếu'));
      await t.pumpAndSettle();
      expect(find.text('Kết thúc trình chiếu?'), findsNothing);
      expect(router.state.uri.path, '/');
    },
  );

  testWidgets(
    'presentation refresh reloads board, stack and selected detail together',
    (t) async {
      final e = HEnv();
      e.http.respond = (r) => r4Reply(r.path);
      final router = await mountR4(
        t,
        e,
        const PresentationScreen(projectId: 'p'),
      );
      addTearDown(router.dispose);
      await t.tap(find.text('A101'));
      await t.pumpAndSettle();
      final future = t.widget<kit.Screen>(find.byType(kit.Screen)).onRefresh!();
      await t.pumpAndSettle();
      await future;
      for (final suffix in [
        '/presentation-board',
        '/stack-plan',
        '/units/u/detail',
      ]) {
        expect(e.http.seen.where((r) => r.path.endsWith(suffix)), hasLength(2));
      }
    },
  );

  testWidgets('saving within typing debounce stores current controls', (
    t,
  ) async {
    final e = HEnv();
    e.http.respond = (r) => r.method == 'POST' && r.path.endsWith('/saved')
        ? const Reply(200, {
            'id': 'saved',
            'name': 'Khách An',
            'params': <String, String>{},
          })
        : r4Reply(r.path);
    final router = await mountR4(t, e, const SearchUnitsScreen());
    addTearDown(router.dispose);
    t
        .widget<kit.SearchBar>(find.byType(kit.SearchBar))
        .onChangeText('Mới nhập');
    await t.pump();
    await t.tap(find.text('Lưu bộ lọc này'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
    final field = t.widget<kit.Field>(
      find.byWidgetPredicate(
        (w) => w is kit.Field && w.label == 'Lưu bộ lọc đang dùng',
      ),
    );
    field.onChangeText!('Khách An');
    await t.pump();
    t
        .widget<kit.Button>(find.widgetWithText(kit.Button, 'Lưu bộ lọc'))
        .onPress();
    await t.pumpAndSettle();
    final request = e.http.seen.singleWhere(
      (r) => r.method == 'POST' && r.path.endsWith('/saved'),
    );
    expect((request.data as Map)['params'], {
      'status': 'available',
      'q': 'Mới nhập',
    });
    expect(find.text('Đã lưu bộ lọc.'), findsOneWidget);
  });

  testWidgets(
    'local search keeps partial coverage, unknown prices and matches after page failure',
    (t) async {
      final e = HEnv();
      e.http.respond = (r) => r.path == '/sales/units/search'
          ? r.queryParameters['page'] == 2
                ? const Reply(503, {'message': 'Chưa tải được trang tiếp theo'})
                : Reply(200, {
                    'data': [
                      {...hUnit, 'bedrooms': 2, 'price_min': '3900000000'},
                      {'id': 'unknown', 'code': 'UNKNOWN', 'bedrooms': 2},
                      {
                        'id': 'expensive',
                        'code': 'EXPENSIVE',
                        'bedrooms': 2,
                        'price_min': '4100000000',
                      },
                    ],
                    'total': 60,
                    'page': 1,
                    'per_page': 30,
                  })
          : r4Reply(r.path);
      final router = await mountR4(t, e, const SearchUnitsScreen());
      addTearDown(router.dispose);
      t.widget<kit.SearchBar>(find.byType(kit.SearchBar)).onFilter!();
      await t.pumpAndSettle();
      t
          .widget<kit.Chip>(
            find.byWidgetPredicate((w) => w is kit.Chip && w.label == '2 PN'),
          )
          .onPress!();
      await t.pump();
      t
          .widget<kit.Field>(
            find.byWidgetPredicate(
              (w) => w is kit.Field && w.label == 'Giá tối đa (tỷ đồng)',
            ),
          )
          .onChangeText!('4');
      await t.pump();
      t
          .widget<kit.Sheet>(
            find.byWidgetPredicate(
              (w) => w is kit.Sheet && w.title == 'Lọc & sắp xếp',
            ),
          )
          .onClose();
      await t.pumpAndSettle();
      expect(find.text('1 phù hợp trong 3/60 căn đã tải'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('UNKNOWN'),
        200,
        scrollable: verticalR4.first,
      );
      expect(find.text('EXPENSIVE'), findsNothing);
      expect(
        find.text('Chưa có giá — chưa xác nhận ngân sách'),
        findsOneWidget,
      );
      await t.scrollUntilVisible(
        find.text('Tải thêm'),
        200,
        scrollable: verticalR4.first,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Tải thêm'));
      await t.pumpAndSettle();
      expect(find.text('Chưa tải được trang tiếp theo'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('P-A101'),
        -200,
        scrollable: verticalR4.first,
      );
      expect(find.text('P-A101'), findsOneWidget);
      for (final request in e.http.seen.where(
        (r) => r.path == '/sales/units/search',
      )) {
        expect(request.queryParameters.containsKey('bedrooms'), isFalse);
        expect(request.queryParameters.containsKey('budget'), isFalse);
      }
    },
  );

  testWidgets('presentation detail opens without moving the board', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r4Reply(r.path);
    final router = await mountR4(
      t,
      e,
      const PresentationScreen(projectId: 'p'),
    );
    addTearDown(router.dispose);
    final position = t.getTopLeft(find.text('A101'));
    await t.tap(find.text('A101'));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('A101')), position);
    expect(find.text('Thông tin căn'), findsOneWidget);
    expect(find.text('Căn P-A101'), findsOneWidget);
    expect(find.textContaining('3999999999'), findsNothing);
  });

  testWidgets('unsupported notification has no navigation affordance', (
    t,
  ) async {
    final e = HEnv();
    e.http.respond = (r) => r4Reply(r.path);
    final router = await mountR4(t, e, const NotificationsScreen());
    addTearDown(router.dispose);
    expect(find.byIcon(Ionicons.chevronForward), findsNothing);
    expect(find.text('Chỉ thông báo'), findsOneWidget);
  });

  testWidgets('search status changes request immediately', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r4Reply(r.path);
    final router = await mountR4(t, e, const SearchUnitsScreen());
    addTearDown(router.dispose);
    await t.tap(find.text('Đã bán'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1));
    expect(
      e.http.seen
          .where((r) => r.path == '/sales/units/search')
          .last
          .queryParameters['status'],
      'sold',
    );
  });

  testWidgets('advanced search and compact saving are available', (t) async {
    final e = HEnv();
    e.http.respond = (r) => r4Reply(r.path);
    final router = await mountR4(t, e, const SearchUnitsScreen());
    addTearDown(router.dispose);
    expect(find.text('Lưu bộ lọc này'), findsOneWidget);
    final search = t.widget<kit.SearchBar>(find.byType(kit.SearchBar));
    search.onFilter!();
    await t.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is kit.Section && w.title == 'Phòng ngủ'),
      findsOneWidget,
    );
    await t.ensureVisible(find.text('Giá tối đa (tỷ đồng)'));
    expect(find.text('Giá tối đa (tỷ đồng)'), findsOneWidget);
  });

  testWidgets('unit loan and compare actions stay outside scrolling content', (
    t,
  ) async {
    final e = HEnv();
    final router = await mountR4(t, e, const UnitScreen(id: 'u'));
    addTearDown(router.dispose);
    expect(find.text('Tính lãi vay căn này').hitTestable(), findsOneWidget);
    expect(find.text('Thêm vào so sánh').hitTestable(), findsOneWidget);
    expect(
      t.widget<Scaffold>(find.byType(Scaffold).first).bottomNavigationBar,
      isNotNull,
    );
  });

  testWidgets('share launch failure retains the created link', (t) async {
    final e = HEnv();
    e.http.respond = (r) =>
        r.path.endsWith('/share-links') && r.method == 'POST'
        ? const Reply(200, {'id': 'created', 'url_path': '/s/created'})
        : hReply(r.path);
    final router = await mountR4(t, e, const ShareLinksScreen(projectId: 'p'));
    addTearDown(router.dispose);
    await t.tap(find.text('Tạo link mới và gửi'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Đã tạo link; chưa mở được chia sẻ'),
      findsOneWidget,
    );
    expect(find.text('Sao chép link'), findsWidgets);
    expect(
      e.http.seen.where(
        (r) => r.path.endsWith('/share-links') && r.method == 'POST',
      ),
      hasLength(1),
    );
  });
}
