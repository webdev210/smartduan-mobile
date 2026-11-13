import 'package:ionicons/ionicons.dart';

import '../../ui/network_image.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/public.dart';
import '../../auth/session.dart';
import '../../config.dart';
import '../../ui/catalog.dart';
import '../../ui/developer_chip.dart';
import '../../ui/format.dart';
import '../../ui/in_app.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/map_embed.dart';
import '../../ui/overview.dart';
import '../../ui/project_card.dart';
import '../../ui/project_filter.dart';
import '../../ui/theme.dart' as c;
import '../../ui/tour360.dart';
import '../../ui/favorite_button.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(fetchPublicProjectProvider(code));
    final signedIn =
        ref.watch(sessionProvider).status == SessionStatus.signedIn;
    final p = q.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.name ?? 'Dự án'),
        actions: [FavoriteButton(code: code, name: p?.name ?? 'dự án')],
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: c.card,
              child: Row(
                spacing: 16,
                children: [
                  Expanded(
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
                              : priceLabel(p.priceFrom)
                                    .replaceFirst(RegExp(r'^Giá từ '), 'từ '),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: kit.Button(
                      icon: Ionicons.lockOpenOutline,
                      title: 'Xem bảng hàng',
                      onPress: () => _openBoard(context, ref, signedIn, p?.id),
                    ),
                  ),
                ],
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
        if (facts.isNotEmpty)
          kit.Card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 14,
              children: [
                for (final (label, value) in facts)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        kit.Muted(label, style: const TextStyle(fontSize: 12)),
                        kit.Body(value),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (p.developer case final d?)
          kit.Card(
            accessibilityLabel: 'Chủ đầu tư ${d.name}, xem các dự án khác',
            onPress: () =>
                openDeveloper(context, id: d.id, name: d.name, slug: d.slug),
            child: LayoutBuilder(
              builder: (context, constraints) => Flex(
                mainAxisSize: MainAxisSize.min,
                direction:
                    constraints.maxWidth /
                            MediaQuery.textScalerOf(context).scale(1) <
                        400
                    ? Axis.vertical
                    : Axis.horizontal,
                spacing: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Ionicons.businessOutline,
                        size: 20,
                        color: c.muted,
                      ),
                    ),
                  Flexible(
                    fit: FlexFit.loose,
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const kit.Muted('Chủ đầu tư'),
                        kit.Body(d.name),
                      ],
                    ),
                  ),
                  const Text('Dự án khác', style: TextStyle(color: c.link)),
                  const Icon(Ionicons.chevronForward, size: 16, color: c.link),
                ],
              ),
            ),
          ),
        if (overview.summary != null || overview.usp.isNotEmpty)
          kit.Section(
            title: 'Tổng quan',
            children: [
              if (overview.summary case final summary?) _PreviewText(summary),
              if (overview.usp.isNotEmpty) _Bullets(items: overview.usp),
            ],
          ),
        if (overview.specs.isNotEmpty)
          kit.Section(
            title: 'Thông tin dự án',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth /
                            MediaQuery.textScalerOf(context).scale(1) <
                        400
                    ? 1
                    : 2;
                return Column(
                  spacing: 10,
                  children: [
                    for (var i = 0; i < overview.specs.length; i += columns)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 10,
                          children: [
                            for (final spec
                                in overview.specs.skip(i).take(columns))
                              Expanded(
                                child: kit.Card(
                                  children: [
                                    kit.Muted(
                                      spec.label,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    kit.Body(spec.value),
                                  ],
                                ),
                              ),
                            if (columns == 2 && i + 1 == overview.specs.length)
                              const Expanded(child: SizedBox()),
                          ],
                        ),
                      ),
                  ],
                );
              },
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
                      child: GestureDetector(
                        onTap: () => openInApp(context, f.url!, f.name),
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
                            kit.Muted(f.name, numberOfLines: 1),
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
                    kit.Card(
                      padding: EdgeInsets.zero,
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
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 4,
                            children: [
                              kit.Body(d.name),
                              if (d.description case final description?)
                                _PreviewText(description),
                            ],
                          ),
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
            child: kit.Card(
              child: _PreviewList(
                children: [
                  for (final e in p.progress!)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 2,
                      children: [
                        kit.Muted(fmtDate(e.occurredOn)),
                        kit.Body(e.title),
                        if (e.body case final body?) _PreviewText(body),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (docs.isNotEmpty)
          kit.Section(
            title: 'Tài liệu',
            child: kit.Card(
              padding: EdgeInsets.zero,
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
          ),
        if (p.faqs?.isNotEmpty == true)
          kit.Section(
            title: 'Hỏi đáp',
            child: kit.Card(
              padding: EdgeInsets.zero,
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
          ),
        if (overview.source case final source?)
          kit.Card(
            onPress: () => openInApp(context, source, 'Nguồn thông tin dự án'),
            child: Row(
              spacing: 10,
              children: [
                const Icon(Ionicons.globeOutline, size: 20, color: c.muted),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const kit.Body('Nguồn thông tin dự án'),
                      kit.Muted(
                        source.replaceFirst(RegExp(r'^https?://'), ''),
                        numberOfLines: 1,
                      ),
                    ],
                  ),
                ),
                const Icon(Ionicons.openOutline, size: 16, color: c.subtle),
              ],
            ),
          ),
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
        kit.Card(
          style: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.brandBorder),
          ),
          children: [
            const kit.H2('Bảng hàng, giá từng căn và chính sách'),
            if (signedIn) ...[
              const kit.Muted(
                'Xem rổ hàng, quỹ căn và tài liệu nội bộ nếu dự án đã phân bổ cho bạn.',
              ),
              kit.Button(
                title: 'Mở dự án nội bộ',
                onPress: () => _openBoard(context, ref, true, p.id),
              ),
            ] else ...[
              const kit.Muted(
                'Dành cho chuyên viên kinh doanh. Đăng nhập để xem rổ hàng, quỹ căn và tài liệu nội bộ của dự án.',
              ),
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: kit.Button(
                      title: 'Đăng nhập',
                      onPress: () => _openBoard(context, ref, false, p.id),
                    ),
                  ),
                  Expanded(
                    child: kit.Button(
                      title: 'Đăng ký sale',
                      kind: 'secondary',
                      onPress: () {
                        ref.read(publicApiProvider).trackCtaClick(p.id);
                        context.push('/dang-ky');
                      },
                    ),
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
            Expanded(child: _PreviewText(item)),
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

class _PreviewText extends StatefulWidget {
  const _PreviewText(this.text);
  final String text;
  @override
  State<_PreviewText> createState() => _PreviewTextState();
}

class _PreviewTextState extends State<_PreviewText> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const style = TextStyle(fontSize: 16, height: 1.6, color: c.text);
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: 6,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final long = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: expanded ? null : 6,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (long)
            kit.Button(
              kind: 'link',
              title: expanded ? 'Thu gọn' : 'Xem thêm',
              onPress: () => setState(() => expanded = !expanded),
            ),
        ],
      );
    },
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
                PageView(
                  onPageChanged: (i) => setState(() => index = i),
                  children: [
                    for (final m in widget.images)
                      AppNetworkImage(
                        mediaUrl(m.url)!,
                        fit: BoxFit.cover,
                        semanticLabel: m.caption ?? widget.name,
                        errorBuilder: (_, _, _) =>
                            ProjectMedia(name: widget.name),
                      ),
                  ],
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
