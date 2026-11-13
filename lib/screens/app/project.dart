import 'package:ionicons/ionicons.dart';

import '../../ui/network_image.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/content.dart';
import '../../api/errors.dart';
import '../../api/projects.dart';
import '../../api/sales.dart';
import '../../api/units.dart';
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../ui/format.dart';
import '../../ui/in_app.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/map_embed.dart';
import '../../ui/overview.dart';
import '../../ui/project_filter.dart' show projectStatus;
import '../../ui/tour360.dart';
import '../../ui/search.dart';

bool _hiddenWhenDenied(Object? error) =>
    error is ApiError && (error.status == 403 || error.status == 404);

class ProjectScreen extends ConsumerStatefulWidget {
  const ProjectScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  String q = '';
  bool downloading = false;
  Object? downloadError;
  SessionState? loggedSession;
  Future<void> download(String id) async {
    if (downloading) return;
    final session = ref.read(sessionProvider);
    setState(() {
      downloading = true;
      downloadError = null;
    });
    try {
      final url = await ref.read(documentDownloadUrlProvider)(id);
      if (mounted && identical(session, ref.read(sessionProvider))) {
        await openInApp(context, url, 'Tài liệu', true);
      }
    } catch (e) {
      if (mounted && identical(session, ref.read(sessionProvider))) {
        setState(() => downloadError = e);
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    ref.listen(sessionProvider, (_, _) {
      if (mounted) setState(() => downloadError = null);
    });
    final query = ref.watch(fetchProjectProvider(widget.id));
    final p = query.value;
    final details = p == null ? null : _details(p, session.roles);
    if (p != null && !identical(loggedSession, session)) {
      loggedSession = session;
      unawaited(
        Future<void>.microtask(() {
          if (mounted && identical(session, ref.read(sessionProvider))) {
            return ref.read(logActivityProvider)({
              'kind': 'project',
              'project_id': widget.id,
              'path': '/du-an/${widget.id}',
            });
          }
        }),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(query.asData?.value.name ?? 'Dự án')),
      body: kit.Screen(
        onRefresh: () async {
          // Contacts are audited reads and deliberately excluded from refresh.
          ref.invalidate(
            fetchMediaProvider((projectId: widget.id, mediaType: null)),
          );
          ref.invalidate(fetchPolicyScopesProvider(widget.id));
          ref.invalidate(fetchPolicyHistoryProvider(widget.id));
          ref.invalidate(fetchDocumentsProvider(widget.id));
          ref.invalidate(fetchProgressProvider(widget.id));
          ref.invalidate(fetchFaqsProvider(widget.id));
          ref.invalidate(fetchSubdivisionsProvider(widget.id));
          await ref
              .refresh(fetchProjectProvider(widget.id).future)
              .then((_) {});
        },
        children: [
          if (query.error case ApiError(status: 403))
            const kit.Notice(
              tone: 'warn',
              text: 'Tài khoản của bạn chưa xem được chi tiết dự án này (sale tự do chỉ xem danh mục). Xin xác nhận F2 để mở bảng hàng.',
            )
          else if (query.error case ApiError(status: 404))
            kit.Notice(tone: 'warn', text: notAssignedText(session.roles))
          else
            kit.AsyncView(
              value: query,
              onRetry: () => ref.invalidate(fetchProjectProvider(widget.id)),
              builder: (_) => details!,
            ),
        ],
      ),
    );
  }

  Widget _details(Project p, Roles roles) {
    // These subscriptions remain mounted while searching or refreshing the
    // project, so the audited contacts read runs once for this screen's life.
    final media = ref.watch(
      fetchMediaProvider((projectId: p.id, mediaType: null)),
    );
    final policy = ref.watch(fetchPolicyScopesProvider(p.id));
    final history = ref.watch(fetchPolicyHistoryProvider(p.id));
    final enums = ref.watch(fetchEnumsProvider);
    final docs = ref.watch(fetchDocumentsProvider(p.id));
    final progress = ref.watch(fetchProgressProvider(p.id));
    final faqs = ref.watch(fetchFaqsProvider(p.id));
    final subdivisions = ref.watch(fetchSubdivisionsProvider(p.id));
    final contacts = ref.watch(fetchContactsProvider(p.id));
    final all = media.asData?.value ?? <MediaItem>[];
    final images = all.where(
      (m) => m.mediaType.isEmpty || m.mediaType == 'image',
    );
    final tours = all.where((m) => m.mediaType == 'tour360' && isHttp(m.url));
    final videos = all.where(
      (m) => m.mediaType == 'video' && isHttp(m.embedUrl ?? m.url),
    );
    final training = all
        .where((m) => m.mediaType == 'training' && isHttp(m.url))
        .toList();
    final plans = floorPlansOf(p.overviewJson).where((f) => isHttp(f.url));
    final searching = q.trim().isNotEmpty;
    String scope(String? fund) => fund == null || fund.isEmpty
        ? 'CSBH chung'
        : enums.asData?.value.fundLabels[fund] ?? fund;
    final blocks = smartFilter(
      subdivisions.asData?.value ?? <Subdivision>[],
      q,
      (d) => [d.name, d.code, d.description],
    );
    final policies = smartFilter(
      policy.asData?.value ?? <Policy>[],
      q,
      (x) => [x.title, x.summary, scope(x.fund)],
    );
    final soon = smartFilter(
      upcomingPolicies(policy.asData?.value ?? [], history.asData?.value ?? []),
      q,
      (x) => [x.title, x.summary, scope(x.fund)],
    );
    final people = smartFilter(
      contacts.asData?.value ?? <Contact>[],
      q,
      (c) => [c.fullName, c.roleLabel],
    );
    final files = smartFilter(
      docs.asData?.value ?? <Doc>[],
      q,
      (d) => [d.title],
    );
    final steps = smartFilter(
      progress.asData?.value ?? <ProgressItem>[],
      q,
      (x) => [x.title, x.body],
    );
    final lessons = smartFilter(training, q, (m) => [m.caption]);
    final answers = smartFilter(
      faqs.asData?.value ?? <Faq>[],
      q,
      (f) => [f.question, f.answer],
    );
    final nothing =
        searching &&
        [
          blocks,
          policies,
          soon,
          people,
          files,
          steps,
          lessons,
          answers,
        ].every((rows) => rows.isEmpty);
    void push(String path, [Map<String, String> params = const {}]) =>
        context.push(
          Uri(
            path: path,
            queryParameters: params.isEmpty ? null : params,
          ).toString(),
        );
    Widget card(String title, List<Widget> children) =>
        kit.Card(children: [kit.H2(title), ...children]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        if (images.isNotEmpty)
          _Strip(
            items: [
              for (final m in images) (url: m.url, name: m.caption ?? p.name),
            ],
            width: 260,
          ),
        if (projectStatus[p.status] case final st?)
          kit.Pill(
            label: st.label,
            color: Color(
              int.parse(st.color.replaceFirst('#', 'ff'), radix: 16),
            ),
          ),
        kit.H1(p.name),
        if ([
          p.address,
          p.ward,
          p.district,
          p.province,
        ].any((s) => s?.isNotEmpty == true))
          kit.Muted(
            [
              p.address,
              p.ward,
              p.district,
              p.province,
            ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
          ),
        kit.Card(
          children: [
            kit.Row(label: 'Chủ đầu tư', value: p.developerName ?? '—'),
            kit.Row(label: 'Giá từ', value: fmtPrice(p.priceFrom)),
            kit.Row(
              label: 'Cập nhật rổ hàng',
              value: fmtDate(p.inventoryUpdatedAt, true),
            ),
          ],
        ),
        if (screens['salesFloor']!(roles))
          kit.Button(
            icon: Ionicons.gridOutline,
            title: 'Mở bảng hàng',
            onPress: () => push('/bang-hang/${p.id}', {'name': p.name}),
          ),
        if (p.basketEmbedUrl case final url? when url.isNotEmpty)
          kit.Button(
            icon: Ionicons.basketOutline,
            title: 'Mở rổ hàng ngoài',
            kind: 'secondary',
            onPress: () => push('/ro-hang', {'project': p.id, 'url': url}),
          ),
        kit.Card(
          padding: EdgeInsets.zero,
          children: [
            if (screens['salesFloor']!(roles))
              kit.ListItem(
                icon: Ionicons.trophyOutline,
                title: 'Top căn',
                subtitle: 'Căn giá tốt, căn đẹp, căn góc theo từng loại',
                onPress: () => push('/top-can/${p.id}', {'name': p.name}),
              ),
            if (screens['shareLinks']!(roles)) ...[
              const kit.Divider(),
              kit.ListItem(
                icon: Ionicons.tvOutline,
                title: 'Trình chiếu cho khách',
                subtitle: 'Bảng hàng giá làm tròn, không lộ dữ liệu nội bộ',
                onPress: () => push('/trinh-chieu/${p.id}'),
              ),
              const kit.Divider(),
              kit.ListItem(
                icon: Ionicons.shareSocialOutline,
                title: 'Chia sẻ cho khách',
                subtitle:
                    'Tạo link xem bảng hàng, theo dõi lượt xem và liên hệ',
                onPress: () => push('/chia-se/${p.id}', {'name': p.name}),
              ),
            ],
          ],
        ),
        kit.Button(
          kind: 'soft',
          icon: Ionicons.chatbubblesOutline,
          title: 'Yêu cầu tư vấn dự án này',
          onPress: () => push('/tu-van', {'projectId': p.id, 'name': p.name}),
        ),
        kit.SearchBar(
          value: q,
          onChangeText: (s) => setState(() => q = s),
          placeholder: 'Tìm trong dự án: tài liệu, chính sách, hỏi đáp…',
        ),
        if (nothing)
          kit.Empty(
            icon: Ionicons.searchOutline,
            text: 'Không thấy “${q.trim()}” trong dự án này.',
            action: (
              label: 'Xoá từ khoá',
              onPress: () => setState(() => q = ''),
            ),
          ),
        if (!searching && p.description != null && p.description!.isNotEmpty)
          card('Tổng quan', [kit.Body(p.description!)]),
        if (!searching && plans.isNotEmpty)
          card('Mặt bằng', [
            _Strip(
              items: [for (final f in plans) (url: f.url!, name: f.name)],
              width: 220,
              caption: true,
            ),
          ]),
        if (media.hasError && !_hiddenWhenDenied(media.error))
          card('Hình ảnh & 360', [
            kit.ErrorBox(
              error: media.error,
              onRetry: () => ref.invalidate(
                fetchMediaProvider((projectId: p.id, mediaType: null)),
              ),
            ),
          ]),
        if (!searching && (tours.isNotEmpty || videos.isNotEmpty))
          card('Hình ảnh & 360', [
            for (final m in tours)
              Tour360(url: m.url, name: m.caption ?? p.name, cover: p.coverUrl),
            for (final m in videos)
              kit.Button(
                kind: 'secondary',
                icon: Ionicons.playCircleOutline,
                title: m.caption ?? 'Xem video dự án',
                onPress: () => openInApp(
                  context,
                  m.embedUrl ?? m.url,
                  m.caption ?? 'Video dự án',
                ),
              ),
          ]),
        if (!searching &&
            p.lat != null &&
            p.lat != '' &&
            p.lng != null &&
            p.lng != '')
          card('Vị trí', [MapEmbed(lat: p.lat, lng: p.lng, name: p.name)]),
        if (subdivisions.hasError && !_hiddenWhenDenied(subdivisions.error))
          card('Phân khu', [
            kit.ErrorBox(
              error: subdivisions.error,
              onRetry: () => ref.invalidate(fetchSubdivisionsProvider(p.id)),
            ),
          ]),
        if (blocks.isNotEmpty)
          card('Phân khu', [
            for (final d in blocks)
              kit.ListItem(
                padding: const EdgeInsets.symmetric(vertical: 14),
                title: d.name,
                subtitle: [
                  '${d.totalUnits} căn',
                  if (d.priceMin != null && d.priceMin != '')
                    '${fmtPrice(d.priceMin)} – ${fmtPrice(d.priceMax)}',
                  d.description,
                ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                onPress: () => push('/bang-hang/${p.id}', {
                  'name': p.name,
                  'blockId': d.blockId,
                }),
              ),
          ]),
        if (policy.hasError && !_hiddenWhenDenied(policy.error))
          card('Chính sách bán hàng', [
            kit.ErrorBox(
              error: policy.error,
              onRetry: () => ref.invalidate(fetchPolicyScopesProvider(p.id)),
            ),
          ]),
        if (history.hasError && !_hiddenWhenDenied(history.error))
          card('Chính sách bán hàng', [
            kit.ErrorBox(
              error: history.error,
              onRetry: () => ref.invalidate(fetchPolicyHistoryProvider(p.id)),
            ),
          ]),
        if (policies.isNotEmpty || soon.isNotEmpty)
          card('Chính sách bán hàng', [
            for (final x in policies)
              _PolicyBlock(
                policy: x,
                scope: scope(x.fund),
                onFile: _openPolicy,
              ),
            for (final x in soon)
              _PolicyBlock(
                policy: x,
                scope: 'Sắp áp dụng · ${scope(x.fund)}',
                onFile: _openPolicy,
              ),
          ]),
        if (people.isNotEmpty)
          card('Đầu mối dự án', [
            for (final c in people)
              kit.Row(
                label: '${c.fullName} · ${c.roleLabel}',
                value: kit.Button(
                  kind: 'link',
                  title: c.phone,
                  onPress: () {
                    if (!c.phone.contains('★')) {
                      openInApp(context, 'tel:${c.phone}');
                    }
                  },
                ),
              ),
          ]),
        if (docs.hasError && !_hiddenWhenDenied(docs.error))
          card('Tài liệu', [
            kit.ErrorBox(
              error: docs.error,
              onRetry: () => ref.invalidate(fetchDocumentsProvider(p.id)),
            ),
          ]),
        if (files.isNotEmpty)
          card('Tài liệu', [
            const kit.Muted('Link tải có hạn, tối đa 10 lần/giờ.'),
            for (final d in files)
              kit.Row(
                label: d.title,
                value: kit.Button(
                  kind: 'link',
                  title: 'Tải',
                  disabled: downloading,
                  onPress: () => download(d.id),
                ),
              ),
          ]),
        if (downloadError != null)
          kit.Notice(tone: 'error', text: errorMessage(downloadError)),
        if (progress.hasError && !_hiddenWhenDenied(progress.error))
          card('Tiến độ', [
            kit.ErrorBox(
              error: progress.error,
              onRetry: () => ref.invalidate(fetchProgressProvider(p.id)),
            ),
          ]),
        if (steps.isNotEmpty)
          card('Tiến độ', [
            for (final x in steps)
              kit.Body(
                '${fmtDate(x.occurredOn)} — ${x.title ?? ''}${x.body == null || x.body!.isEmpty ? '' : '\n${x.body}'}',
              ),
          ]),
        if (lessons.isNotEmpty)
          card('Đào tạo', [
            for (final m in lessons)
              kit.Row(
                label: m.caption ?? 'Tài liệu đào tạo',
                value: kit.Button(
                  kind: 'link',
                  title: 'Mở',
                  onPress: () =>
                      openInApp(context, m.url, m.caption ?? 'Đào tạo'),
                ),
              ),
          ]),
        if (faqs.hasError && !_hiddenWhenDenied(faqs.error))
          card('Hỏi đáp', [
            kit.ErrorBox(
              error: faqs.error,
              onRetry: () => ref.invalidate(fetchFaqsProvider(p.id)),
            ),
          ]),
        if (answers.isNotEmpty)
          kit.Section(
            title: 'Hỏi đáp',
            child: kit.Card(
              padding: EdgeInsets.zero,
              children: [
                for (final f in answers)
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
        if ([
          media,
          policy,
          history,
          docs,
          progress,
          faqs,
          subdivisions,
        ].any((value) => value.hasError && !_hiddenWhenDenied(value.error)))
          const kit.Notice(
            tone: 'warn',
            text: 'Một số phần không tải được. Kéo xuống để thử lại.',
          ),
        if ([
          media,
          policy,
          history,
          docs,
          progress,
          faqs,
          subdivisions,
          contacts,
        ].any((value) => value.isLoading))
          const kit.Loading(),
      ],
    );
  }

  void _openPolicy(String url) {
    if (isDocumentId(url)) {
      download(url);
    } else {
      openInApp(context, url, 'Chính sách bán hàng');
    }
  }
}

class _PolicyBlock extends StatelessWidget {
  const _PolicyBlock({
    required this.policy,
    required this.scope,
    required this.onFile,
  });
  final Policy policy;
  final String scope;
  final void Function(String) onFile;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 4,
    children: [
      kit.Body(
        policy.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      kit.Muted(
        '$scope · Hiệu lực ${fmtDate(policy.effectiveFrom)}${policy.effectiveTo == null || policy.effectiveTo!.isEmpty ? '' : ' – ${fmtDate(policy.effectiveTo)}'}',
      ),
      if (policy.summary != null && policy.summary!.isNotEmpty)
        kit.Body(policy.summary!),
      if (policy.fileUrl != null && policy.fileUrl!.isNotEmpty)
        kit.Button(
          kind: 'link',
          title: 'Xem file chính sách',
          onPress: () => onFile(policy.fileUrl!),
        ),
    ],
  );
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.items,
    required this.width,
    this.caption = false,
  });
  final List<({String url, String name})> items;
  final double width;
  final bool caption;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final x in items)
          Semantics(
            button: true,
            label: x.name,
            child: GestureDetector(
              onTap: () => openInApp(context, x.url, x.name),
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AppNetworkImage(
                        x.url,
                        width: width,
                        height: width * 3 / 5,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => SizedBox(
                          height: width * 3 / 5,
                          child: const Icon(Ionicons.imageOutline),
                        ),
                      ),
                    ),
                    if (caption) kit.Muted(x.name, numberOfLines: 1),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
