import 'dart:math' as math;

import 'package:material_ui/material_ui.dart' hide Card, Chip, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/me.dart';
import '../../api/projects.dart';
import '../../api/public.dart';
import '../../api/sales.dart';
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row, Divider;
import '../../ui/menu.dart';
import '../../ui/project_browser.dart';
import '../../ui/project_card.dart';
import '../../ui/project_compare.dart';
import '../../ui/project_compare_kit.dart';
import '../../ui/favorite_button.dart';
import 'menu_tab.dart' show menuIcon;
import 'projects_tab.dart' show TabProject;

final tabSurveyProvider = sessionQuery((ref) {
  signedInClient(ref);
  return ref.watch(meApiProvider).getSurveyDue();
});
const _hotFilters = PublicFilters(hot: '1', sort: 'hot', perPage: 8);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<HomeScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(sessionProvider).roles;
    final hasProjects = screens['projects']!(roles);
    final projects = hasProjects ? ref.watch(fetchAllProjectsProvider) : null;
    final showPublic = !hasProjects || projects?.value?.isEmpty == true;
    final hot = showPublic
        ? ref.watch(listPublicProjectsProvider(_hotFilters))
        : null;
    final announcements = screens['announcements']!(roles)
        ? ref.watch(fetchAnnouncementsProvider(1))
        : null;
    final survey = ref.watch(tabSurveyProvider);
    final unread = ref.watch(fetchNotificationsProvider).value?.unread;
    final favorites = ref.watch(savedProjectsProvider).value ?? <String>[];
    final comparing = ref.watch(projectCompareProvider).isNotEmpty;
    final rows = showPublic
        ? hot?.value?.data ?? <PublicProject>[]
        : projects?.value?.map(TabProject.new).toList() ?? <PublicProject>[];
    void open(PublicProject p) => context.push(
      showPublic
          ? '/cong-khai/${Uri.encodeComponent(p.code)}'
          : '/du-an/${Uri.encodeComponent(p.id)}',
    );
    void all() => context.push(
      showPublic
          ? Uri(path: '/kham-pha', queryParameters: {'q': q.trim()}).toString()
          : Uri(
              path: '/du-an',
              queryParameters: {
                'q': q.trim(),
                'at': '${DateTime.now().millisecondsSinceEpoch}',
              },
            ).toString(),
    );
    final cardWidth = math.min(380.0, MediaQuery.sizeOf(context).width - 64);
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Screen(
            onRefresh: () async {
              ref.invalidate(tabSurveyProvider);
              if (hasProjects) ref.invalidate(fetchAllProjectsProvider);
              if (showPublic) {
                ref.invalidate(listPublicProjectsProvider(_hotFilters));
              }
              if (announcements != null) {
                ref.invalidate(fetchAnnouncementsProvider(1));
              }
              if (hasProjects) await ref.read(fetchAllProjectsProvider.future);
            },
            children: [
              Row(
                spacing: 10,
                children: [
                  Image.asset(
                    'assets/smartland-mark.png',
                    width: 32,
                    height: 32,
                    semanticLabel: 'Smartland',
                  ),
                  const Expanded(child: H2('Smart Dự Án')),
                ],
              ),
              SearchBar(
                value: q,
                onChangeText: (v) => setState(() => q = v),
                onSubmit: all,
                placeholder: 'Tìm dự án, khu vực, chủ đầu tư…',
                maxLength: 60,
              ),
              ProjectQuickFind(q: q, projects: rows, onOpen: open, onAll: all),
              ListItem(
                title: unread == null
                    ? 'Thông báo'
                    : 'Thông báo · $unread chưa đọc',
                onPress: () => context.push('/thong-bao'),
              ),
              if (announcements != null)
                Section(
                  title: 'Bảng tin mới',
                  action: (
                    label: 'Xem tất cả',
                    onPress: () => context.push('/bang-tin'),
                  ),
                  child: AsyncView(
                    value: announcements,
                    onRetry: () =>
                        ref.invalidate(fetchAnnouncementsProvider(1)),
                    builder: (data) => Column(
                      children: [
                        if (data.data.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Muted('Chưa có tin.'),
                          ),
                        for (final a in data.data.take(3))
                          ListItem(
                            title: a.title,
                            subtitle: fmtDate(a.publishedAt),
                            onPress: () => context.push(
                              '/bang-tin/${Uri.encodeComponent(a.id)}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Section(
                title: showPublic ? 'Dự án nổi bật trên sàn' : 'Dự án của bạn',
                action: (
                  label: 'Xem tất cả',
                  onPress: () =>
                      context.push(showPublic ? '/kham-pha' : '/du-an'),
                ),
                child: showPublic
                    ? AsyncView(
                        value: hot!,
                        onRetry: () => ref.invalidate(
                          listPublicProjectsProvider(_hotFilters),
                        ),
                        builder: (_) => _rail(
                          rows,
                          cardWidth,
                          open,
                          'Chưa có dự án nổi bật.',
                        ),
                      )
                    : AsyncView(
                        value: projects!,
                        onRetry: () => ref.invalidate(fetchAllProjectsProvider),
                        builder: (_) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (rows.isEmpty) const Muted('Chưa có dự án nào.'),
                            for (final p in rows.take(8)) ...[
                              ListItem(
                                title: p.name,
                                subtitle: p.inventoryUpdatedAt == null
                                    ? 'Chưa có thời điểm cập nhật'
                                    : 'Cập nhật ${fmtDate(p.inventoryUpdatedAt, true)}',
                                onPress: () => open(p),
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (p.code.isNotEmpty &&
                                      p.isPublic != false) ...[
                                    FavoriteButton(code: p.code, name: p.name),
                                    CompareChip(code: p.code, name: p.name),
                                  ],
                                  TextButton(
                                    onPressed: () => context.push(
                                      '/bang-hang/${Uri.encodeComponent(p.id)}',
                                    ),
                                    child: const Text('Bảng hàng'),
                                  ),
                                  TextButton(
                                    onPressed: () => context.push(
                                      '/bien-dong/${Uri.encodeComponent(p.id)}',
                                    ),
                                    child: const Text('Biến động'),
                                  ),
                                ],
                              ),
                              const Divider(),
                            ],
                          ],
                        ),
                      ),
              ),
              Section(
                title: 'Yêu thích',
                action: (
                  label: 'Xem tất cả',
                  onPress: () => context.push('/da-luu'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final p
                        in rows
                            .where(
                              (p) =>
                                  p.code.isNotEmpty &&
                                  p.isPublic != false &&
                                  favorites.contains(p.code),
                            )
                            .take(3))
                      ListItem(
                        title: p.name,
                        subtitle: showPublic ? null : 'Bảng hàng',
                        onPress: () => showPublic
                            ? open(p)
                            : context.push(
                                '/bang-hang/${Uri.encodeComponent(p.id)}',
                              ),
                      ),
                    TextButton(
                      onPressed: () => context.push('/quan-tam'),
                      child: const Text('Nhận thông báo dự án'),
                    ),
                  ],
                ),
              ),
              Section(
                title: 'Truy cập nhanh',
                action: (
                  label: 'Tất cả tính năng',
                  onPress: () => context.push('/menu'),
                ),
                child: Column(
                  children: [
                    for (final item in quickActions(roles))
                      ListItem(
                        icon: menuIcon(item.icon),
                        title: item.label,
                        subtitle: item.hint,
                        onPress: () => context.push(item.href),
                      ),
                  ],
                ),
              ),
              if (comparing) const SizedBox(height: 70),
              if (survey.value == true) const _SurveyCard(),
            ],
          ),
          const CompareDock(bottom: 12),
        ],
      ),
    );
  }

  Widget _rail(
    List<PublicProject> rows,
    double width,
    void Function(PublicProject) open,
    String empty,
  ) {
    if (rows.isEmpty) return Muted(empty);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        // ponytail: this rail has at most eight cards with two-line names;
        // measure content if card metadata gains unbounded text.
        height:
            width * 10 / 16 + 310 * MediaQuery.textScalerOf(context).scale(1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            for (final p in rows)
              ProjectCard(p: p, width: width, onPress: () => open(p)),
          ],
        ),
      ),
    );
  }
}

class _SurveyCard extends ConsumerStatefulWidget {
  const _SurveyCard();
  @override
  ConsumerState<_SurveyCard> createState() => _SurveyState();
}

class _SurveyState extends ConsumerState<_SurveyCard> {
  int? score;
  bool? refer;
  bool sending = false, failed = false;
  Future<void> send(bool dismissed) async {
    if (sending) return;
    setState(() {
      sending = true;
      failed = false;
    });
    try {
      await ref
          .read(meApiProvider)
          .submitSurvey(
            dismissed
                ? {'dismissed': true}
                : {'ease_score': score!, 'would_refer': refer!},
          );
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) {
        ref.invalidate(tabSurveyProvider);
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    children: [
      const H2('Góp ý nhanh'),
      const Muted('App dễ dùng thế nào? (1 = khó, 5 = rất dễ)'),
      Chips(
        children: [
          for (final n in [1, 2, 3, 4, 5])
            Chip(
              label: '$n',
              active: score == n,
              onPress: () => setState(() => score = n),
            ),
        ],
      ),
      const Muted('Bạn có giới thiệu cho đồng nghiệp?'),
      Chips(
        children: [
          for (final (v, label) in [(true, 'Có'), (false, 'Không')])
            Chip(
              label: label,
              active: refer == v,
              onPress: () => setState(() => refer = v),
            ),
        ],
      ),
      if (failed)
        const Notice(tone: 'error', text: 'Gửi không được, thử lại sau.'),
      ButtonGroup(
        spacing: 8,
        children: [
          Button(
            kind: 'secondary',
            title: 'Để sau',
            disabled: sending,
            onPress: () => send(true),
          ),
          Button(
            title: 'Gửi',
            disabled: score == null || refer == null,
            loading: sending,
            onPress: () => send(false),
          ),
        ],
      ),
    ],
  );
}
