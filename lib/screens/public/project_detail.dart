import 'package:ionicons/ionicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../ui/network_image.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/public.dart';
import '../../auth/session.dart';
import '../../auth/roles.dart';
import '../../config.dart';
import '../../ui/catalog.dart';
import '../../ui/developer_chip.dart';
import '../../ui/format.dart';
import '../../ui/in_app.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/preview_text.dart';
import '../../ui/map_embed.dart';
import '../../ui/overview.dart';
import '../../ui/project_card.dart';
import '../../ui/project_filter.dart';
import '../../ui/project_facts.dart';
import '../../ui/theme.dart' as c;
import '../../ui/tour360.dart';
import '../../ui/favorite_button.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(fetchPublicProjectProvider(code));
    final session = ref.watch(sessionProvider);
    final signedIn = session.status == SessionStatus.signedIn;
    final p = q.asData?.value;
    final directBoard =
        signedIn && p != null && screens['salesFloor']!(session.roles);
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.name ?? 'Dự án'),
        actions: [
          if (p != null)
            Builder(
              builder: (context) => kit.IconButton(
                icon: Ionicons.shareSocialOutline,
                label: 'Chia sẻ trang dự án',
                onPress: () async {
                  final box = context.findRenderObject()! as RenderBox;
                  try {
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            '${webUrl.isEmpty ? 'https://smartduan.vn' : webUrl}/du-an/${Uri.encodeComponent(p.code)}',
                        title: p.name,
                        sharePositionOrigin:
                            box.localToGlobal(Offset.zero) & box.size,
                      ),
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Không mở được chia sẻ. Vui lòng thử lại.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          FavoriteButton(code: code, name: p?.name ?? 'dự án'),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: kit.Screen(
                children: [
                  kit.AsyncView(
                    value: q,
                    onRetry: () =>
                        ref.invalidate(fetchPublicProjectProvider(code)),
                    builder: (p) => _Detail(p: p, signedIn: signedIn),
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: 640),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: c.card,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 340 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: stacked
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 16) / 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const kit.Muted(
                              'Giá bán',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              p == null
                                  ? '…'
                                  : priceLabel(
                                      p.priceFrom,
                                    ).replaceFirst(RegExp(r'^Giá từ '), 'từ '),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: stacked
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 16) * 2 / 3,
                        child: kit.Pressable(
                          label: directBoard ? 'Bảng hàng' : 'Xem bảng hàng',
                          disabled: p == null,
                          onPress: () => directBoard
                              ? context.push(
                                  Uri(
                                    path:
                                        '/bang-hang/${Uri.encodeComponent(p.id)}',
                                    queryParameters: {'name': p.name},
                                  ).toString(),
                                )
                              : _openBoard(context, ref, signedIn, p?.id),
                          // ponytail: kit.Button is single-line, reuse Pressable
                          // until the shared button allows scaled labels to wrap.
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              spacing: 8,
                              children: [
                                const Icon(
                                  Ionicons.lockOpenOutline,
                                  size: 20,
                                  color: c.card,
                                ),
                                Expanded(
                                  child: Text(
                                    directBoard ? 'Bảng hàng' : 'Xem bảng hàng',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: c.card,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openBoard(
  BuildContext context,
  WidgetRef ref,
  bool signedIn,
  String? id,
) {
  if (signedIn && id != null) {
    context.push('/du-an/${Uri.encodeComponent(id)}');
    return;
  }
  if (id != null) ref.read(publicApiProvider).trackCtaClick(id);
  context.push('/dang-nhap');
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.p, required this.signedIn});
  final PublicProject p;
  final bool signedIn;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = (p.media ?? <PublicMedia>[])
        .where((m) => m.mediaType == 'image' && mediaUrl(m.url) != null)
        .toList();
    final video = (p.media ?? <PublicMedia>[])
        .where((m) => m.mediaType == 'video' && isHttp(m.embedUrl ?? m.url))
        .firstOrNull;
    final tour =
        p.tour360Url ??
        (p.media ?? <PublicMedia>[])
            .where((m) => m.mediaType == 'tour360')
            .firstOrNull
            ?.url;
    final overview = parseOverview(p.overviewJson),
        amenities = amenitiesOf(p.overviewJson);
    final plans = floorPlansOf(p.overviewJson)
        .where((f) => isHttp(f.url))
        .toList();
    final place = [
      p.ward,
      p.district,
      p.province,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final oldPlace = [
      p.wardOld,
      p.districtOld,
      p.provinceOld,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final facts = <(String, String)>[
      if (typeLabel[p.projectType] case final label?) ('Loại hình', label),
      if (projectStatus[p.status] case final status?)
        ('Giai đoạn', status.label),
      if (p.priceFrom != null && p.priceFrom!.isNotEmpty)
        ('Giá từ', fmtPrice(p.priceFrom)),
    ];
    final docs = p.documents.where((d) => isHttp(d.url)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 22,
      children: [
        _Gallery(
          name: p.name,
          status: p.status,
          images: images,
          cover: p.coverUrl,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(
              p.name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            if (place.isNotEmpty || p.address?.isNotEmpty == true)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Ionicons.locationOutline,
                      size: 16,
                      color: c.muted,
                    ),
                  ),
                  Expanded(
                    child: kit.Muted(
                      '${p.address?.isNotEmpty == true ? '${p.address}${place.isEmpty ? '' : ', $place'}' : place}${oldPlace.isEmpty ? '' : ' (trước đây: $oldPlace)'}',
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (tour != null)
          kit.Section(
            title: 'Tour 360°',
            child: Tour360(url: tour, name: p.name, cover: p.coverUrl),
          ),
        if (video != null)
          kit.Button(
            kind: 'secondary',
            icon: Ionicons.playCircleOutline,
            title: 'Xem video dự án',
            onPress: () => openInApp(
              context,
              video.embedUrl ?? video.url,
              video.caption ?? 'Video dự án',
            ),
          ),
        if (facts.isNotEmpty) ProjectFacts(entries: facts),
        if (p.developer case final d?)
          kit.Card(
            accessibilityLabel: 'Chủ đầu tư ${d.name}, xem các dự án khác',
            onPress: () =>
                openDeveloper(context, id: d.id, name: d.name, slug: d.slug),
            child: Row(
              spacing: 12,
              children: [
                if (mediaUrl(d.logoUrl) case final logo?)
                  AppNetworkImage(
                    logo,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Ionicons.businessOutline,
                      size: 20,
                      color: c.muted,
                    ),
                  )
                else
                  const Icon(
                    Ionicons.businessOutline,
                    size: 24,
                    color: c.muted,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      const kit.Muted('Chủ đầu tư'),
                      kit.Body(d.name),
                      const Text('Dự án khác', style: TextStyle(color: c.link)),
                    ],
                  ),
                ),
                const Icon(Ionicons.chevronForward, size: 20, color: c.link),
              ],
            ),
          ),
        if (overview.summary != null || overview.usp.isNotEmpty)
          kit.Section(
            title: 'Tổng quan',
            children: [
              if (overview.summary case final summary?)
                PreviewText(
                  summary,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: c.text,
                  ),
                ),
              if (overview.usp.isNotEmpty) _Bullets(items: overview.usp),
            ],
          ),
        if (overview.specs.isNotEmpty)
          kit.Section(
            title: 'Thông tin dự án',
            child: ProjectFacts(
              entries: [
                for (final spec in overview.specs) (spec.label, spec.value),
              ],
            ),
          ),
        if (amenities.isNotEmpty)
          kit.Section(
            title: 'Tiện ích',
            child: _Bullets(items: amenities),
          ),
        if (p.lat?.isNotEmpty == true && p.lng?.isNotEmpty == true)
          kit.Section(
            title: 'Vị trí',
            child: MapEmbed(lat: p.lat, lng: p.lng, name: p.name),
          ),
        if (plans.isNotEmpty)
          kit.Section(
            title: 'Mặt bằng',
            child: _PreviewList(
              horizontal: true,
              children: [
                for (final f in plans)
                  SizedBox(
                    width: 220,
                    child: Semantics(
                      button: true,
                      label: f.name,
                      child: kit.Pressable(
                        onPress: () => openInApp(context, f.url!, f.name),
                        child: Column(
                          spacing: 6,
                          children: [
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: AppNetworkImage(
                                f.url!,
                                fit: BoxFit.cover,
                                semanticLabel: f.name,
                                errorBuilder: (_, _, _) =>
                                    const ColoredBox(color: c.quiet),
                              ),
                            ),
                            kit.Muted(f.name),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (p.subdivisions?.isNotEmpty == true)
          kit.Section(
            title: 'Phân khu',
            children: [
              const kit.Muted(
                'Giá và bảng hàng từng căn hiển thị sau khi đăng nhập.',
              ),
              _PreviewList(
                children: [
                  for (final d in p.subdivisions!)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        if (mediaUrl(d.coverUrl) case final cover?)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: AppNetworkImage(
                              cover,
                              fit: BoxFit.cover,
                              semanticLabel: d.name,
                              errorBuilder: (_, _, _) =>
                                  const ColoredBox(color: c.quiet),
                            ),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 4,
                          children: [
                            kit.Body(d.name),
                            if (d.description case final description?)
                              PreviewText(
                                description,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  color: c.text,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        if (p.progress?.isNotEmpty == true)
          kit.Section(
            title: 'Tiến độ',
            child: _PreviewList(
              children: [
                for (final e in p.progress!)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 2,
                    children: [
                      kit.Muted(fmtDate(e.occurredOn)),
                      kit.Body(e.title),
                      if (e.body case final body?)
                        PreviewText(
                          body,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: c.text,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        if (docs.isNotEmpty)
          kit.Section(
            title: 'Tài liệu',
            child: _PreviewList(
              children: [
                for (final d in docs)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(
                        Ionicons.documentTextOutline,
                        size: 20,
                        color: c.brand,
                      ),
                      title: Text(d.name ?? 'Tài liệu'),
                      trailing: const Icon(Ionicons.openOutline, size: 16),
                      onTap: () =>
                          openInApp(context, d.url!, d.name ?? 'Tài liệu'),
                    ),
                  ),
              ],
            ),
          ),
        if (p.faqs?.isNotEmpty == true)
          kit.Section(
            title: 'Hỏi đáp',
            children: [
              for (final f in p.faqs!)
                Material(
                  color: Colors.transparent,
                  child: kit.FaqItem(
                    key: ValueKey(f.id),
                    question: f.question,
                    answer: f.answer,
                  ),
                ),
            ],
          ),
        if (overview.source case final source?)
          ProjectSourcePreview(name: p.name, source: source, cover: p.coverUrl),
        if (!signedIn)
          kit.Card(
            children: [
              const kit.H2('Nhận bảng giá & tư vấn'),
              const kit.Muted(
                'Để lại số điện thoại, chuyên viên sẽ gọi lại cho bạn.',
              ),
              kit.Button(
                kind: 'secondary',
                icon: Ionicons.callOutline,
                title: 'Nhận tư vấn',
                onPress: () {
                  ref.read(publicApiProvider).trackCtaClick(p.id);
                  openInApp(
                    context,
                    '${webUrl.isEmpty ? 'https://smartduan.vn' : webUrl}/du-an/${Uri.encodeComponent(p.code)}#lead',
                    'Nhận tư vấn',
                  );
                },
              ),
            ],
          ),
        kit.Section(
          title: 'Bảng hàng, giá từng căn và chính sách',
          children: [
            if (signedIn) ...[
              const kit.Muted(
                'Xem rổ hàng, quỹ căn và tài liệu nội bộ nếu dự án đã phân bổ cho bạn.',
              ),
              kit.Button(
                kind: 'secondary',
                title: 'Mở dự án nội bộ',
                onPress: () => _openBoard(context, ref, true, p.id),
              ),
            ] else ...[
              const kit.Muted(
                'Dành cho chuyên viên kinh doanh. Đăng nhập để xem rổ hàng, quỹ căn và tài liệu nội bộ của dự án.',
              ),
              kit.ButtonGroup(
                spacing: 10,
                children: [
                  kit.Button(
                    kind: 'secondary',
                    title: 'Đăng nhập',
                    onPress: () => _openBoard(context, ref, false, p.id),
                  ),
                  kit.Button(
                    title: 'Đăng ký sale',
                    kind: 'link',
                    onPress: () {
                      ref.read(publicApiProvider).trackCtaClick(p.id);
                      context.push('/dang-ky');
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class ProjectSourcePreview extends StatelessWidget {
  const ProjectSourcePreview({
    super.key,
    required this.name,
    required this.source,
    this.cover,
  });
  final String name, source;
  final String? cover;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(source)?.host ?? '';
    final image = mediaUrl(cover);
    return kit.Card(
      accessibilityLabel: 'Mở trang giới thiệu dự án $name trên $host',
      onPress: () => openInApp(context, source, 'Nguồn thông tin dự án'),
      children: [
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(color: c.quiet),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Ionicons.openOutline,
                        size: 16,
                        color: c.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  const kit.Body('Xem trang giới thiệu dự án'),
                  kit.Muted(host, numberOfLines: 1),
                ],
              ),
            ),
            const Icon(Ionicons.openOutline, size: 20, color: c.link),
          ],
        ),
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) => _PreviewList(
    children: [
      for (final item in items)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            const Text('•', style: TextStyle(color: c.brand)),
            Expanded(
              child: PreviewText(
                item,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: c.text,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}

class _PreviewList extends StatefulWidget {
  const _PreviewList({required this.children, this.horizontal = false});
  final List<Widget> children;
  final bool horizontal;
  @override
  State<_PreviewList> createState() => _PreviewListState();
}

class _PreviewListState extends State<_PreviewList> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 9,
    children: [
      if (widget.horizontal)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 12,
            children: widget.children
                .take(expanded ? widget.children.length : 5)
                .toList(),
          ),
        )
      else
        ...widget.children.take(expanded ? widget.children.length : 5),
      if (widget.children.length > 5)
        kit.Button(
          kind: 'link',
          title: expanded ? 'Thu gọn' : 'Xem thêm (${widget.children.length})',
          onPress: () => setState(() => expanded = !expanded),
        ),
    ],
  );
}

class _Gallery extends StatefulWidget {
  const _Gallery({
    required this.name,
    required this.status,
    required this.images,
    required this.cover,
  });
  final String name, status;
  final List<PublicMedia> images;
  final String? cover;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int index = 0;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: widget.images.isEmpty
        ? ProjectMedia(
            name: widget.name,
            uri: widget.cover,
            status: widget.status,
          )
        : AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                PageView.builder(
                  onPageChanged: (i) => setState(() => index = i),
                  itemCount: widget.images.length,
                  itemBuilder: (context, i) {
                    final m = widget.images[i];
                    return AppNetworkImage(
                      mediaUrl(m.url)!,
                      fit: BoxFit.cover,
                      semanticLabel: m.caption ?? widget.name,
                      errorBuilder: (_, _, _) =>
                          ProjectMedia(name: widget.name),
                    );
                  },
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${index + 1}/${widget.images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}
