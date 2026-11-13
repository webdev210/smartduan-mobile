import 'dart:collection';

import 'package:material_ui/material_ui.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/ui/kit.dart' show SearchBar;
import 'package:smartduan/ui/project_browser.dart';
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/project_filter.dart';

final browserProjects = [
  PublicProject(
    id: 'a',
    code: 'A',
    name: 'Hồ Tây',
    status: 'selling',
    province: 'Hà Nội',
    projectType: 'apartment',
    priceFrom: '3000000000',
    developer: const ProjectDeveloper(id: 'd1', name: 'Sun Group'),
  ),
  PublicProject(
    id: 'b',
    code: 'B',
    name: 'Biển Xanh',
    status: 'upcoming',
    province: 'Đà Nẵng',
    projectType: 'resort',
    priceFrom: '1000000000',
    developer: const ProjectDeveloper(id: 'd2', name: 'Vingroup'),
  ),
];

Future<void> pumpBrowser(
  WidgetTester tester, {
  List<PublicProject>? projects,
  bool loading = false,
  Object? error,
  ProjectFilter initial = emptyProjectFilter,
  VoidCallback? retry,
  ValueChanged<PublicProject>? open,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ProjectBrowser(
          projects: projects ?? browserProjects,
          loading: loading,
          error: error,
          onRetry: retry ?? () {},
          onRefresh: () async {},
          onOpen: open ?? (_) {},
          initial: initial,
          emptyText: 'Chưa có dự án công khai nào.',
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('presentation changes reuse cached catalogue derivations', (
    tester,
  ) async {
    final projects = _CountingProjects(browserProjects);
    await pumpBrowser(tester, projects: projects);
    await tester.pumpAndSettle();
    final reads = projects.reads;
    await tester.tap(find.bySemanticsLabel('Xem dạng danh sách gọn'));
    await tester.pumpAndSettle();
    expect(projects.reads, reads);
    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pumpAndSettle();
    expect(projects.reads, reads);
  });
  testWidgets('retained catalogue reports refresh failure above its cards', (
    tester,
  ) async {
    var retries = 0;
    await pumpBrowser(tester, error: Exception(), retry: () => retries++);
    expect(find.text('Có lỗi xảy ra, thử lại sau'), findsOneWidget);
    expect(find.byType(ProjectCard), findsWidgets);
    await tester.tap(find.text('Thử lại'));
    expect(retries, 1);
  });
  for (final (option, expected) in [
    ('Căn hộ · 1', 'Hồ Tây'),
    ('Dưới 2 tỷ · 1', 'Biển Xanh'),
    ('Miền Bắc · 1', 'Hồ Tây'),
    ('Sun Group · 1', 'Hồ Tây'),
  ]) {
    testWidgets('filter sheet applies $option', (tester) async {
      await pumpBrowser(tester);
      await tester.tap(find.bySemanticsLabel('Bộ lọc'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(option));
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem 1 dự án'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectCard), findsOneWidget);
      expect(find.text(expected), findsOneWidget);
    });
  }
  testWidgets('search is accent insensitive and clears a no-match filter', (
    tester,
  ) async {
    await pumpBrowser(tester);
    await tester.enterText(find.byType(TextField), 'ho tay');
    await tester.pumpAndSettle();
    expect(find.text('1 dự án'), findsOneWidget);
    expect(find.byType(ProjectCard), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'không tồn tại');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Không có dự án khớp. Thử từ khoá ngắn hơn hoặc bỏ bớt bộ lọc.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Xoá tìm kiếm & bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('2 dự án'), findsOneWidget);
    expect(tester.widget<SearchBar>(find.byType(SearchBar)).value, '');
  });
  testWidgets(
    'quick status chips toggle filtering and compact results open projects',
    (tester) async {
      PublicProject? opened;
      await pumpBrowser(tester, open: (p) => opened = p);
      await tester.tap(find.text('Đang bán · 1'));
      await tester.pumpAndSettle();
      expect(find.text('1 dự án'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Xem dạng danh sách gọn'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectRow), findsOneWidget);
      await tester.tap(find.text('Hồ Tây'));
      expect(opened?.code, 'A');
      await tester.tap(find.text('Đang bán · 1'));
      await tester.pumpAndSettle();
      expect(find.text('2 dự án'), findsOneWidget);
    },
  );
  testWidgets('filter sheet applies province and sort immediately', (
    tester,
  ) async {
    await pumpBrowser(tester);
    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Lọc & sắp xếp'), findsOneWidget);
    await tester.tap(find.text('Giá thấp → cao'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hà Nội · 1'));
    await tester.tap(find.text('Hà Nội · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem 1 dự án'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectCard), findsOneWidget);
    expect(find.text('Hồ Tây'), findsOneWidget);
    expect(find.text('Giá thấp → cao'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('suggestions select a province and clear the query', (
    tester,
  ) async {
    await pumpBrowser(tester);
    await tester.enterText(find.byType(TextField), 'ha noi');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Lọc theo khu vực Hà Nội, 1 dự án'));
    await tester.pumpAndSettle();
    expect(tester.widget<SearchBar>(find.byType(SearchBar)).value, '');
    expect(find.text('1 dự án'), findsOneWidget);
    expect(find.text('Hà Nội'), findsWidgets);
  });
  testWidgets('loading, empty and retry states remain reachable', (
    tester,
  ) async {
    await pumpBrowser(tester, projects: [], loading: true);
    expect(find.byType(ProjectCardSkeleton), findsNWidgets(2));
    await pumpBrowser(tester, projects: []);
    expect(find.text('Chưa có dự án công khai nào.'), findsOneWidget);
    var retried = false;
    await pumpBrowser(
      tester,
      projects: [],
      error: Exception('offline'),
      retry: () => retried = true,
    );
    await tester.tap(find.text('Thử lại'));
    expect(retried, isTrue);
  });
}

class _CountingProjects extends ListBase<PublicProject> {
  _CountingProjects(this.source);
  final List<PublicProject> source;
  int reads = 0;
  @override
  int get length => source.length;
  @override
  set length(int value) => throw UnsupportedError('read only');
  @override
  PublicProject operator [](int index) {
    reads++;
    return source[index];
  }

  @override
  void operator []=(int index, PublicProject value) =>
      throw UnsupportedError('read only');
}
