import '../../ui/network_image.dart';

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart'
    hide Card, Chip, Divider, Hero, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/public.dart';
import '../../auth/messages.dart';
import '../../auth/session.dart';
import '../../ui/catalog.dart';
import '../../ui/developer_chip.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/project_browser.dart';
import '../../ui/project_card.dart';
import '../../ui/project_compare.dart';
import '../../ui/project_compare_kit.dart';
import '../../ui/regions.dart';
import '../../ui/theme.dart' as c;

typedef _HomeState = ({String q, String region, bool menu, int slide});

String footerDisplayLabel(String label) {
  final value = label.replaceFirst(RegExp(r'^Dự án '), '');
  if (value.isEmpty) return value;
  final first = value.characters.first;
  return '${first.toUpperCase()}${value.substring(first.length)}';
}

final _homeProvider = NotifierProvider.autoDispose<_HomeController, _HomeState>(
  _HomeController.new,
);

class _HomeController extends Notifier<_HomeState> {
  @override
  _HomeState build() => (q: '', region: 'bac', menu: false, slide: 0);
  void search(String q) => state = (
    q: q,
    region: state.region,
    menu: state.menu,
    slide: state.slide,
  );
  void region(String region) => state = (
    q: state.q,
    region: region,
    menu: state.menu,
    slide: state.slide,
  );
  void menu(bool menu) => state = (
    q: state.q,
    region: state.region,
    menu: menu,
    slide: state.slide,
  );
  void slide(int slide) => state = (
    q: state.q,
    region: state.region,
    menu: state.menu,
    slide: slide,
  );
}

void _openProject(BuildContext context, PublicProject p) =>
    context.push('/cong-khai/${Uri.encodeComponent(p.code)}');
void _explore(BuildContext context, [Map<String, String> params = const {}]) =>
    context.push(
      Uri(
        path: '/kham-pha',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );

class PublicHome extends ConsumerWidget {
  const PublicHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_homeProvider);
    final comparing = ref.watch(projectCompareProvider).isNotEmpty;
    final control = ref.read(_homeProvider.notifier);
    final projects = ref.watch(listAllPublicProjectsProvider);
    const hotFilter = PublicFilters(hot: '1');
    final hot = ref.watch(listPublicProjectsProvider(hotFilter));
    final stats = ref.watch(fetchPublicStatsProvider);
    final news = ref.watch(listPublicPostsProvider((kind: 'news', perPage: 3)));
    final events = ref.watch(
      listPublicPostsProvider((kind: 'event', perPage: 3)),
    );
    final devs = ref.watch(listPublicDevelopersProvider);
    final footer = ref.watch(listFooterLinksProvider);
    final places = ref.watch(fetchProvincesProvider);
    final all = projects.value ?? <PublicProject>[];
    final slides = heroProjects(hot.value?.data ?? <PublicProject>[], all);
    final featured = featuredProjects(all);
    final byRegion = all
        .where((p) => inRegion(p.province, state.region))
        .take(6)
        .toList();
    final provinces = provinceCounts(all, provinceAliases(places.value ?? []));
    final byType = [
      for (final l in footer.value ?? <FooterLink>[])
        if (footerCatalogParams(l.href) case final params?)
          (link: l, params: params),
    ];
    final ended = sessionEndedMessage(
      ref.watch(sessionProvider.select((s) => s.endedReason)),
    );
    final contact = stats.value?.contact;
    final width = MediaQuery.sizeOf(context).width;
    final cardW = math.min(300.0, width * .74);
    void search() {
      final q = ref.read(_homeProvider).q.trim();
      _explore(context, q.isEmpty ? {} : {'q': q});
    }

    Future<void> refresh() async {
      await Future.wait<Object?>([
        ref.refresh(listAllPublicProjectsProvider.future),
        ref.refresh(listPublicProjectsProvider(hotFilter).future),
        ref.refresh(fetchPublicStatsProvider.future),
        ref.refresh(listPublicPostsProvider((kind: 'news', perPage: 3)).future),
        ref.refresh(
          listPublicPostsProvider((kind: 'event', perPage: 3)).future,
        ),
        ref.refresh(listPublicDevelopersProvider.future),
        ref.refresh(listFooterLinksProvider.future),
        ref.refresh(fetchProvincesProvider.future),
      ]);
    }

    void menuGo(String path) {
      control.menu(false);
      context.push(path);
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                spacing: 10,
                children: [
                  Image.asset(
                    'assets/icon.png',
                    width: 32,
                    height: 32,
                    semanticLabel: 'Smartland',
                  ),
                  const Expanded(
                    child: Text(
                      'Smart Dự Án',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                  Button(
                    title: 'Đăng nhập',
                    icon: Ionicons.personCircleOutline,
                    size: 'sm',
                    onPress: () => context.push('/dang-nhap'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Screen(
                    padded: false,
                    onRefresh: refresh,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: 6,
                          bottom: comparing ? 100 : 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 28,
                          children: [
                            if (ended != null)
                              _pad(
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: 8,
                                  children: [
                                    Notice(tone: 'warn', text: ended),
                                    Button(
                                      title: 'Đăng nhập lại',
                                      kind: 'secondary',
                                      onPress: () => context.push('/dang-nhap'),
                                    ),
                                  ],
                                ),
                              ),
                            Appear(
                              child: projects.isLoading
                                  ? _pad(
                                      Skeleton(
                                        height: (width - 40) * 1.1,
                                        style: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                        ),
                                      ),
                                    )
                                  : AsyncView(
                                      value: projects,
                                      onRetry: () => ref.invalidate(
                                        listAllPublicProjectsProvider,
                                      ),
                                      builder: (_) => _HeroSlides(
                                        slides: slides,
                                        index: state.slide,
                                        onChanged: control.slide,
                                      ),
                                    ),
                            ),
                            Appear(
                              delay: 80,
                              child: _pad(
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: 14,
                                  children: [
                                    SearchBar(
                                      value: state.q,
                                      onChangeText: control.search,
                                      onSubmit: search,
                                      placeholder:
                                          'Tìm dự án, khu vực, chủ đầu tư…',
                                      maxLength: 60,
                                      onFilter: search,
                                    ),
                                    ProjectQuickFind(
                                      q: state.q,
                                      projects: all,
                                      onOpen: (p) => _openProject(context, p),
                                      onAll: search,
                                    ),
                                    if (stats.value case final value?)
                                      Card(
                                        child: IntrinsicHeight(
                                          child: Row(
                                            children: [
                                              _trust(
                                                value.projectsSelling,
                                                'dự án đang bán',
                                              ),
                                              const VerticalDivider(
                                                width: 1,
                                                color: c.border,
                                              ),
                                              _trust(
                                                value.developers,
                                                'chủ đầu tư',
                                              ),
                                              if (value.activity7dTotal >
                                                  0) ...[
                                                const VerticalDivider(
                                                  width: 1,
                                                  color: c.border,
                                                ),
                                                _trust(
                                                  value.activity7dTotal,
                                                  'giao dịch 7 ngày',
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              spacing: 12,
                              children: [
                                _pad(
                                  Section(
                                    eyebrow: 'Khám phá dự án',
                                    title: 'Dự án nổi bật',
                                    action: (
                                      label: 'Xem tất cả',
                                      onPress: () => _explore(context),
                                    ),
                                    children: const [],
                                  ),
                                ),
                                _Rail(
                                  items: featured,
                                  cardW: cardW,
                                  loading: projects.isLoading,
                                  empty: 'Chưa có dự án nào đang mở bán.',
                                ),
                              ],
                            ),
                            Column(
                              spacing: 12,
                              children: [
                                _pad(
                                  Section(
                                    title: 'Dự án theo khu vực',
                                    child: Segmented(
                                      value: state.region,
                                      onChange: control.region,
                                      options: [
                                        for (final r in regions)
                                          (
                                            key: r.key,
                                            label: r.label,
                                            count: null,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                _Rail(
                                  items: byRegion,
                                  cardW: cardW,
                                  loading: projects.isLoading,
                                  empty: 'Chưa có dự án tại khu vực này.',
                                ),
                              ],
                            ),
                            _PostBand(
                              title: 'Tin mới',
                              posts: news.value ?? [],
                            ),
                            _PostBand(
                              title: 'Sự kiện',
                              posts: events.value ?? [],
                            ),
                            if (provinces.isNotEmpty ||
                                devs.value?.isNotEmpty == true)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 16,
                                children: [
                                  _pad(
                                    Section(
                                      eyebrow: 'Tìm thêm dự án',
                                      title: 'Theo khu vực',
                                      child: ChipRail(
                                        children: [
                                          for (final p in provinces)
                                            Chip(
                                              icon: Ionicons.locationOutline,
                                              label: '${p.name} · ${p.count}',
                                              onPress: () => _explore(context, {
                                                'province': p.name,
                                              }),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (byType.isNotEmpty)
                                    _pad(
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        spacing: 12,
                                        children: [
                                          const H2('Theo loại hình'),
                                          ChipRail(
                                            children: [
                                              for (final l in byType)
                                                Chip(
                                                  label:
                                                      '${footerDisplayLabel(l.link.label)} · ${l.link.count}',
                                                  onPress: () => _explore(
                                                    context,
                                                    l.params,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (devs.value?.isNotEmpty == true)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      spacing: 12,
                                      children: [
                                        _pad(const H2('Theo chủ đầu tư')),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          child: Row(
                                            spacing: 10,
                                            children: [
                                              for (final d in devs.value!)
                                                DeveloperChip(
                                                  name: d.name,
                                                  logo: d.logoUrl,
                                                  onPress: () => openDeveloper(
                                                    context,
                                                    id: d.id,
                                                    name: d.name,
                                                    slug: d.slug,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            _pad(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 14,
                                children: [
                                  Hero(
                                    children: [
                                      const Text(
                                        'Dành cho chuyên viên kinh doanh',
                                        style: TextStyle(
                                          color: c.gold,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Text(
                                        'Xem bảng hàng, giá từng căn và giữ căn',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 23,
                                          height: 29 / 23,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Text(
                                        'Đăng nhập tài khoản sale để xem rổ hàng được phân bổ, tài liệu và chính sách dự án.',
                                        style: TextStyle(
                                          color: c.onBrandMuted,
                                          fontSize: 14,
                                          height: 20 / 14,
                                        ),
                                      ),
                                      _GoldButton(
                                        title: 'Đăng nhập',
                                        onPress: () =>
                                            context.push('/dang-nhap'),
                                      ),
                                      _AltButton(
                                        title: 'Đăng ký tài khoản sale',
                                        onPress: () => context.push('/dang-ky'),
                                      ),
                                    ],
                                  ),
                                  _Contact(contact: contact),
                                  Button(
                                    title: 'Chính sách bảo vệ dữ liệu cá nhân',
                                    kind: 'link',
                                    onPress: () =>
                                        context.push('/chinh-sach-bao-mat'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const CompareDock(bottom: 12),
                ],
              ),
            ),
            _GuestBar(menu: state.menu, onMenu: () => control.menu(true)),
            Sheet(
              visible: state.menu,
              onClose: () => control.menu(false),
              title: 'Menu',
              children: [
                Hero(
                  children: [
                    const Text(
                      'Đăng nhập để xem bảng hàng, giá từng căn và thông báo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 26 / 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      spacing: 10,
                      children: [
                        Expanded(
                          child: _GoldButton(
                            title: 'Đăng nhập',
                            onPress: () => menuGo('/dang-nhap'),
                          ),
                        ),
                        Expanded(
                          child: _AltButton(
                            title: 'Đăng ký',
                            onPress: () => menuGo('/dang-ky'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Card(
                  padding: EdgeInsets.zero,
                  children: [
                    ListItem(
                      icon: Ionicons.businessOutline,
                      title: 'Tất cả dự án',
                      subtitle: 'Tìm theo tên, khu vực, chủ đầu tư, loại hình',
                      onPress: () => menuGo('/kham-pha'),
                    ),
                    const Divider(),
                    ListItem(
                      icon: Ionicons.calculatorOutline,
                      title: 'Tính lãi vay mua nhà',
                      subtitle: 'Ước tính khoản trả hàng tháng theo giá căn',
                      onPress: () => menuGo('/tinh-lai-vay'),
                    ),
                    const Divider(),
                    ListItem(
                      icon: Ionicons.documentLockOutline,
                      title: 'Chính sách bảo vệ dữ liệu',
                      subtitle: 'Toàn văn chính sách đang áp dụng',
                      onPress: () => menuGo('/chinh-sach-bao-mat'),
                    ),
                  ],
                ),
                _Contact(contact: contact),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _pad(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);
Widget _trust(int value, String label) => Expanded(
  child: Column(
    spacing: 2,
    children: [
      Text(
        '$value',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: c.brand,
        ),
      ),
      Muted(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
    ],
  ),
);

class _HeroSlides extends StatefulWidget {
  const _HeroSlides({
    required this.slides,
    required this.index,
    required this.onChanged,
  });
  final List<PublicProject> slides;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  State<_HeroSlides> createState() => _HeroSlidesState();
}

class _HeroSlidesState extends State<_HeroSlides> {
  PageController? _controller;
  double? _width;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    if (width != _width) {
      _width = width;
      _controller?.dispose();
      _controller = PageController(
        viewportFraction: (width - 28) / (width - 20),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _HeroSlides(:slides, :index, :onChanged) = widget;
    if (slides.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width - 40;
    return Column(
      spacing: 12,
      children: [
        SizedBox(
          height: width * 1.1,
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: PageView.builder(
              padEnds: false,
              controller: _controller,
              onPageChanged: onChanged,
              itemCount: slides.length,
              itemBuilder: (_, i) {
                final p = slides[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Semantics(
                    button: true,
                    label: 'Xem dự án ${p.name}',
                    child: GestureDetector(
                      onTap: () => _openProject(context, p),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // ProjectMedia is fixed at 16:10; fill the taller RN hero without changing Step S.
                            Positioned.fill(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                clipBehavior: Clip.hardEdge,
                                child: SizedBox(
                                  width: width * 1.76,
                                  child: ProjectMedia(
                                    name: p.name,
                                    uri: p.coverUrl,
                                  ),
                                ),
                              ),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xd1000000),
                                    Color(0x61000000),
                                    Color(0x00000000),
                                  ],
                                  stops: [0, .48, .78],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: c.goldGradient,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 4,
                                      children: [
                                        Icon(
                                          Ionicons.flame,
                                          size: 13,
                                          color: c.brandDeep,
                                        ),
                                        Text(
                                          'Nổi bật',
                                          style: TextStyle(
                                            color: c.brandDeep,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 27,
                                      height: 32 / 27,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.7,
                                    ),
                                  ),
                                  Text(
                                    '${[p.district, p.province].whereType<String>().where((s) => s.isNotEmpty).join(', ')}${p.priceFrom != null && p.priceFrom!.isNotEmpty ? ' · Giá từ ${fmtPrice(p.priceFrom)}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: c.onImageMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 6,
                                      children: [
                                        Text(
                                          'Xem dự án',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Icon(Ionicons.arrowForward, size: 16),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (slides.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 6,
            children: [
              for (var i = 0; i < slides.length; i++)
                Container(
                  width: i == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == index ? c.brand : c.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.items,
    required this.cardW,
    required this.loading,
    required this.empty,
  });
  final List<PublicProject> items;
  final double cardW;
  final bool loading;
  final String empty;
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          spacing: 12,
          children: [
            SizedBox(
              width: cardW,
              child: ProjectCardSkeleton(width: cardW),
            ),
            ProjectCardSkeleton(width: cardW),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return Empty(icon: Ionicons.businessOutline, text: empty);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          for (final p in items)
            ProjectCard(
              width: cardW,
              p: p,
              onPress: () => _openProject(context, p),
            ),
        ],
      ),
    );
  }
}

class _PostBand extends StatelessWidget {
  const _PostBand({required this.title, required this.posts});
  final String title;
  final List<PublicPost> posts;
  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    return _pad(
      Section(
        title: title,
        child: Card(
          padding: EdgeInsets.zero,
          children: [
            for (var i = 0; i < posts.length; i++) ...[
              if (i > 0) const Divider(),
              _PostItem(post: posts[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostItem extends StatelessWidget {
  const _PostItem({required this.post});
  final PublicPost post;
  @override
  Widget build(BuildContext context) {
    final src = mediaUrl(post.coverUrl);
    const fallback = ColoredBox(
      color: c.quiet,
      child: Center(
        child: Icon(Ionicons.newspaperOutline, size: 22, color: c.subtle),
      ),
    );
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            context.push('/bai-viet/${Uri.encodeComponent(post.slug)}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            spacing: 12,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 68,
                  child: src == null
                      ? fallback
                      : AppNetworkImage(
                          src,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback,
                        ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    Text(
                      post.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 20 / 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Muted(
                      '${fmtDate(post.eventAt ?? post.publishedAt)}${post.location == null ? '' : ' · ${post.location}'}${post.project == null ? '' : ' · ${post.project!.name}'}',
                      numberOfLines: 1,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({this.contact});
  final PublicContact? contact;
  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      /* Unavailable phone/Zalo apps must not interrupt browsing. */
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    spacing: 10,
    children: [
      if (contact?.hotline?.isNotEmpty == true)
        Expanded(
          child: Button(
            title: contact!.hotline!,
            kind: 'secondary',
            icon: Ionicons.callOutline,
            onPress: () => _launch('tel:${contact!.hotline}'),
          ),
        ),
      if (contact?.zaloUrl?.isNotEmpty == true)
        Expanded(
          child: Button(
            title: 'Chat Zalo',
            kind: 'secondary',
            icon: Ionicons.chatbubbleEllipsesOutline,
            onPress: () => _launch(contact!.zaloUrl!),
          ),
        ),
    ],
  );
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.title, required this.onPress});
  final String title;
  final VoidCallback onPress;
  @override
  Widget build(BuildContext context) => Card(
    padding: EdgeInsets.zero,
    onPress: onPress,
    accessibilityLabel: title,
    style: BoxDecoration(
      gradient: c.goldGradient,
      borderRadius: BorderRadius.circular(16),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: c.brandDeep,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    ),
  );
}

class _AltButton extends StatelessWidget {
  const _AltButton({required this.title, required this.onPress});
  final String title;
  final VoidCallback onPress;
  @override
  Widget build(BuildContext context) => Card(
    padding: EdgeInsets.zero,
    onPress: onPress,
    accessibilityLabel: title,
    style: BoxDecoration(
      color: Colors.transparent,
      border: Border.all(color: c.gold.withValues(alpha: 0.6)),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [],
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    ),
  );
}

class _GuestBar extends StatelessWidget {
  const _GuestBar({required this.menu, required this.onMenu});
  final bool menu;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: c.card,
      boxShadow: [
        BoxShadow(
          color: Color(0x12131313),
          offset: Offset(0, -6),
          blurRadius: 24,
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          for (final item in [
            (
              label: 'Trang chủ',
              icon: Ionicons.home,
              active: true,
              onPress: () {},
            ),
            (
              label: 'Dự án',
              icon: Ionicons.businessOutline,
              active: false,
              onPress: () => _explore(context),
            ),
            (
              label: 'Lãi vay',
              icon: Ionicons.calculatorOutline,
              active: false,
              onPress: () {
                context.push('/tinh-lai-vay');
              },
            ),
            (
              label: 'Menu',
              icon: menu ? Ionicons.menu : Ionicons.menuOutline,
              active: menu,
              onPress: onMenu,
            ),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: item.active,
                label: item.label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: item.onPress,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 62),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 3,
                      children: [
                        Container(
                          width: 56,
                          height: 30,
                          decoration: BoxDecoration(
                            color: item.active
                                ? c.brandSoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            item.icon,
                            size: 22,
                            color: item.active ? c.primary : c.subtle,
                          ),
                        ),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.active ? c.primary : c.subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
