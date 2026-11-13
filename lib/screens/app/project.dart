import '../../api/public.dart';
import '../../ui/catalog.dart';
import '../../ui/developer_chip.dart';
import '../../ui/gallery_viewer.dart';

import 'package:ionicons/ionicons.dart';

import '../../ui/network_image.dart';

import 'dart:async';

import 'package:flutter/services.dart';

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
import '../../ui/preview_text.dart';
import '../../ui/map_embed.dart';
import '../../ui/overview.dart';
import '../../ui/project_facts.dart';
import '../../ui/project_filter.dart' show projectStatus;
import '../../ui/tour360.dart';
import '../../ui/search.dart';
import '../../ui/theme.dart' as c;

bool _hiddenWhenDenied(Object? error) =>
    error is ApiError && (error.status == 403 || error.status == 404);

// Audited reads must never follow Riverpod's default automatic retry policy.
final projectContactsProvider = AsyncNotifierProvider.autoDispose
    .family<SessionQuery<List<Contact>>, List<Contact>, String>(
      (id) => SessionQuery(
        (ref) => ref.watch(projectsApiProvider).fetchContacts(id),
      ),
      retry: (_, _) => null,
    );

class ProjectScreen extends ConsumerStatefulWidget {
  const ProjectScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  String q = '';
  String? downloading;
  final expanded = <String>{};
  Object? downloadError;
  bool showContacts = false;
  SessionState? loggedSession;
  Future<void> download(String id) async {
    if (downloading != null) return;
    final session = ref.read(sessionProvider);
    setState(() {
      downloading = id;
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
      if (mounted) setState(() => downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    ref.listen(sessionProvider, (_, _) {
      if (mounted) setState(() => downloadError = null);
    });
    final query = ref.watch(fetchProjectProvider(widget.id));
    final p = _hiddenWhenDenied(query.error) ? null : query.value;
    final details = p == null ? null : _details(p, session.roles);
    final contacts = p == null
        ? null
        : ref.watch(projectContactsProvider(p.id));
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
      appBar: AppBar(
        title: Text(query.value?.name ?? 'Dự án'),
        actions: [
          if (p != null && screens['shareLinks']!(session.roles))
            IconButton(
              tooltip: 'Chia sẻ dự án',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Ionicons.shareOutline),
              onPressed: () => context.push(
                Uri(
                  path: '/chia-se/${Uri.encodeComponent(p.id)}',
                  queryParameters: {'name': p.name},
                ).toString(),
              ),
            ),
        ],
      ),
      bottomNavigationBar:
          p == null || MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    key: const ValueKey('project-actions'),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stack =
                            constraints.maxWidth < 350 ||
                            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                        final buttons = <Widget>[
                          if (screens['salesFloor']!(session.roles))
                            _ProjectAction(
                              title: 'Bảng hàng',
                              primary: true,
                              onPress: () => context.push(
                                Uri(
                                  path:
                                      '/bang-hang/${Uri.encodeComponent(p.id)}',
                                  queryParameters: {'name': p.name},
                                ).toString(),
                              ),
                            ),
                          if (p.basketEmbedUrl case final url?
                              when url.isNotEmpty)
                            _ProjectAction(
                              title: 'Mở rổ hàng ngoài',
                              icon: Ionicons.basketOutline,
                              onPress: () => context.push(
                                Uri(
                                  path: '/ro-hang',
                                  queryParameters: {
                                    'project': p.id,
                                    'url': url,
                                  },
                                ).toString(),
                              ),
                            ),
                        ];
                        return stack
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                spacing: 8,
                                children: buttons,
                              )
                            : IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  spacing: 8,
                                  children: [
                                    for (final button in buttons)
                                      Expanded(child: button),
                                  ],
                                ),
                              );
                      },
                    ),
                  ),
                ),
              ),
            ),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: kit.Screen(
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
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  sliver: SliverList.separated(
                    itemCount: details?.length ?? 0,
                    itemBuilder: (_, index) => details![index],
                    separatorBuilder: (_, _) => const SizedBox(height: 22),
                  ),
                ),
              ],
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
                    onRetry: () =>
                        ref.invalidate(fetchProjectProvider(widget.id)),
                    builder: (_) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          if (p != null) _contactSheet(p, contacts!),
        ],
      ),
    );
  }

  List<Widget> _details(Project p, Roles roles) {
    // These subscriptions remain mounted while searching or refreshing the
    // project, so the audited contacts read runs once for this screen's life.
    // ponytail: five-row previews keep section rendering bounded; split query
    // consumers if larger sections can load without losing local search coverage.
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
    final contacts = ref.watch(projectContactsProvider(p.id));
    List<T> visible<T>(AsyncValue<List<T>> value) =>
        _hiddenWhenDenied(value.error) ? [] : value.value ?? [];
    final all = visible(media);
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
    final price = priceLabel(p.priceFrom);
    String scope(String? fund) => fund == null || fund.isEmpty
        ? 'CSBH chung'
        : enums.value?.fundLabels[fund] ?? fund;
    final blocks = smartFilter(
      visible(subdivisions),
      q,
      (d) => [d.name, d.code, d.description],
    );
    final policies = smartFilter(
      visible(policy),
      q,
      (x) => [x.title, x.summary, scope(x.fund)],
    );
    final soon = smartFilter(
      upcomingPolicies(visible(policy), visible(history)),
      q,
      (x) => [x.title, x.summary, scope(x.fund)],
    );
    final people = smartFilter(
      visible(contacts),
      q,
      (c) => [c.fullName, c.roleLabel],
    );
    final files = smartFilter(visible(docs), q, (d) => [d.title]);
    final steps = smartFilter(visible(progress), q, (x) => [x.title, x.body]);
    final lessons = smartFilter(training, q, (m) => [m.caption]);
    final answers = smartFilter(
      visible(faqs),
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
        kit.Section(title: title, children: children);
    Widget listCard<T>(
      String title,
      List<T> rows,
      Widget Function(T) row, {
      List<Widget> before = const [],
    }) => card('$title (${rows.length})', [
      ...before,
      for (final item in rows.take(
        searching || expanded.contains(title) ? rows.length : 5,
      ))
        row(item),
      if (rows.length > 5 && !searching)
        kit.Button(
          kind: 'link',
          title: expanded.contains(title)
              ? 'Thu gọn'
              : 'Xem thêm (${rows.length - 5})',
          accessibilityLabel:
              '${expanded.contains(title) ? 'Thu gọn' : 'Xem thêm'} $title',
          onPress: () => setState(
            () => expanded.contains(title)
                ? expanded.remove(title)
                : expanded.add(title),
          ),
        ),
    ]);
    Widget loadingSection(String title) => kit.Section(
      title: title,
      children: [
        for (var i = 0; i < 2; i++)
          kit.Skeleton(height: MediaQuery.textScalerOf(context).scale(60)),
      ],
    );
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          if (projectStatus[p.status] case final st?)
            Text(
              st.label,
              style: TextStyle(
                color: Color(
                  int.parse(st.color.replaceFirst('#', 'ff'), radix: 16),
                ),
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
        ],
      ),
      ProjectFacts(
        valueWidgets: {'Chủ đầu tư': _ProjectDeveloper(project: p)},
        entries: [
          ('Chủ đầu tư', p.developerName ?? '—'),
          (
            price == 'Liên hệ' ? 'Giá bán' : 'Giá từ',
            price.replaceFirst('Giá từ ', ''),
          ),
          ('Cập nhật bảng hàng', fmtDate(p.inventoryUpdatedAt, true)),
        ],
      ),
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
      if (policies.isEmpty &&
          soon.isEmpty &&
          (policy.isLoading || history.isLoading))
        loadingSection('Chính sách bán hàng'),
      if (policies.isNotEmpty || soon.isNotEmpty)
        listCard(
          'Chính sách bán hàng',
          [...policies, ...soon],
          (x) => _PolicyBlock(
            policy: x,
            scope:
                '${soon.contains(x) ? 'Sắp áp dụng · ' : ''}${scope(x.fund)}',
            onFile: _openPolicy,
          ),
        ),
      if (images.isNotEmpty || media.isLoading)
        SizedBox(
          height: 156,
          child: images.isEmpty
              ? const ColoredBox(color: c.quiet)
              : _Strip(
                  items: [
                    for (final m in images)
                      (
                        url: m.url,
                        name: m.caption ?? p.name,
                        caption: m.caption,
                      ),
                  ],
                  width: 260,
                ),
        ),
      if (screens['salesFloor']!(roles) || screens['shareLinks']!(roles))
        kit.Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (screens['salesFloor']!(roles))
                kit.ListItem(
                  icon: Ionicons.trophyOutline,
                  title: 'Top căn',
                  subtitle: 'Căn giá tốt, căn đẹp, căn góc theo từng loại',
                  onPress: () => push('/top-can/${p.id}', {'name': p.name}),
                ),
              if (screens['shareLinks']!(roles)) ...[
                if (screens['salesFloor']!(roles)) const kit.Divider(),
                kit.ListItem(
                  icon: Ionicons.tvOutline,
                  title: 'Trình chiếu cho khách',
                  subtitle: 'Bảng hàng giá làm tròn, không lộ dữ liệu nội bộ',
                  onPress: () => push('/trinh-chieu/${p.id}'),
                ),
              ],
            ],
          ),
        ),
      kit.Button(
        kind: 'soft',
        icon: Ionicons.chatbubblesOutline,
        title: 'Tư vấn dự án',
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
          action: (label: 'Xoá từ khoá', onPress: () => setState(() => q = '')),
        ),
      if (!searching && p.description != null && p.description!.isNotEmpty)
        card('Tổng quan', [PreviewText(p.description!)]),
      if (!searching && plans.isNotEmpty)
        card('Mặt bằng', [
          _Strip(
            items: [
              for (final f in plans)
                (url: f.url!, name: f.name, caption: f.name),
            ],
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
      if (blocks.isEmpty && subdivisions.isLoading) loadingSection('Phân khu'),
      if (blocks.isNotEmpty)
        listCard(
          'Phân khu',
          blocks,
          (d) => kit.ListItem(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
        ),
      if (!_hiddenWhenDenied(contacts.error))
        card('Đầu mối dự án', [
          kit.Button(
            kind: 'link',
            title: 'Gọi / SMS / sao chép',
            onPress: () => setState(() => showContacts = true),
          ),
          if (contacts.hasError) ...[
            const kit.Muted('Chưa tải được đầu mối dự án. Bấm thử lại để tải.'),
            kit.ErrorBox(
              error: contacts.error,
              onRetry: () => ref.invalidate(projectContactsProvider(p.id)),
            ),
          ],
          if (people.isEmpty && contacts.isLoading)
            kit.Skeleton(height: MediaQuery.textScalerOf(context).scale(60)),
          for (final c in people)
            kit.Row(
              padding: EdgeInsets.zero,
              label: '${c.fullName} · ${c.roleLabel}',
              value:
                  c.phone.contains('★') ||
                      c.phone.contains('*') ||
                      c.phone.isEmpty
                  ? kit.Body(c.phone.isEmpty ? '—' : c.phone)
                  : kit.Button(
                      kind: 'link',
                      title: c.phone,
                      onPress: () => openInApp(context, 'tel:${c.phone}'),
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
      if (files.isEmpty && docs.isLoading) loadingSection('Tài liệu'),
      if (files.isNotEmpty)
        listCard(
          'Tài liệu',
          files,
          (d) => kit.Row(
            padding: EdgeInsets.zero,
            label: d.title,
            value: kit.Button(
              kind: 'link',
              title: 'Tải',
              disabled: downloading != null,
              loading: downloading == d.id,
              accessibilityLabel: 'Tải ${d.title}',
              onPress: () => download(d.id),
            ),
          ),
          before: [const kit.Muted('Link tải có hạn, tối đa 10 lần/giờ.')],
        ),
      if (downloadError != null)
        kit.Notice(tone: 'error', text: errorMessage(downloadError)),
      if (progress.hasError && !_hiddenWhenDenied(progress.error))
        card('Tiến độ', [
          kit.ErrorBox(
            error: progress.error,
            onRetry: () => ref.invalidate(fetchProgressProvider(p.id)),
          ),
        ]),
      if (steps.isEmpty && progress.isLoading) loadingSection('Tiến độ'),
      if (steps.isNotEmpty)
        listCard(
          'Tiến độ',
          steps,
          (x) => PreviewText(
            '${fmtDate(x.occurredOn)} — ${x.title ?? ''}${x.body == null || x.body!.isEmpty ? '' : '\n${x.body}'}',
          ),
        ),
      if (lessons.isNotEmpty)
        listCard(
          'Đào tạo',
          lessons,
          (m) => kit.Row(
            padding: EdgeInsets.zero,
            label: m.caption ?? 'Tài liệu đào tạo',
            value: kit.Button(
              kind: 'link',
              title: 'Mở',
              onPress: () => openInApp(context, m.url, m.caption ?? 'Đào tạo'),
            ),
          ),
        ),
      if (faqs.hasError && !_hiddenWhenDenied(faqs.error))
        card('Hỏi đáp', [
          kit.ErrorBox(
            error: faqs.error,
            onRetry: () => ref.invalidate(fetchFaqsProvider(p.id)),
          ),
        ]),
      if (answers.isEmpty && faqs.isLoading) loadingSection('Hỏi đáp'),
      if (answers.isNotEmpty)
        kit.Section(
          title: 'Hỏi đáp',
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
    ];
  }

  Widget _contactSheet(Project p, AsyncValue<List<Contact>> contacts) =>
      kit.Sheet(
        visible: showContacts && !_hiddenWhenDenied(contacts.error),
        onClose: () => setState(() => showContacts = false),
        title: 'Đầu mối dự án',
        child: kit.AsyncView(
          value: contacts,
          onRetry: () => ref.invalidate(projectContactsProvider(p.id)),
          builder: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              if (rows.isEmpty) const kit.Muted('Chưa có đầu mối dự án.'),
              for (final contact in rows) ...[
                kit.Body('${contact.fullName} · ${contact.roleLabel}'),
                kit.Body(contact.phone.isEmpty ? '—' : contact.phone),
                if (contact.phone.isNotEmpty &&
                    !contact.phone.contains('★') &&
                    !contact.phone.contains('*'))
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      kit.Button(
                        title: 'Gọi',
                        kind: 'link',
                        size: 'sm',
                        onPress: () => openInApp(
                          context,
                          Uri(scheme: 'tel', path: contact.phone).toString(),
                        ),
                      ),
                      kit.Button(
                        title: 'Nhắn SMS',
                        kind: 'link',
                        size: 'sm',
                        onPress: () => openInApp(
                          context,
                          Uri(scheme: 'sms', path: contact.phone).toString(),
                        ),
                      ),
                      kit.Button(
                        title: 'Sao chép',
                        kind: 'link',
                        size: 'sm',
                        onPress: () async {
                          String message;
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: contact.phone),
                            );
                            message = 'Đã sao chép số điện thoại';
                          } catch (_) {
                            message = 'Không sao chép được. Vui lòng thử lại.';
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(message)));
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      );

  void _openPolicy(String url) {
    if (isDocumentId(url)) {
      download(url);
    } else {
      openInApp(context, url, 'Chính sách bán hàng');
    }
  }
}

class _ProjectDeveloper extends ConsumerWidget {
  const _ProjectDeveloper({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final developers = project.developerId == null
        ? null
        : ref.watch(listPublicDevelopersProvider);
    final developer = developers?.asData?.value
        .where((d) => d.id == project.developerId)
        .firstOrNull;
    final name = project.developerName ?? '—';
    return kit.Pressable(
      label: 'Chủ đầu tư $name, xem các dự án khác',
      onPress: project.developerId == null
          ? null
          : () => openDeveloper(
              context,
              id: project.developerId!,
              name: name,
              slug: developer?.slug,
            ),
      child: Row(
        spacing: 8,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: developer == null
                ? null
                : switch (mediaUrl(developer.logoUrl)) {
                    final logo? => AppNetworkImage(
                      logo,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      semanticLabel: 'Logo $name',
                      errorBuilder: (_, _, _) =>
                          const Icon(Ionicons.businessOutline),
                    ),
                    null => const Icon(Ionicons.businessOutline),
                  },
          ),
          Expanded(child: kit.Body(name)),
        ],
      ),
    );
  }
}

class _ProjectAction extends StatelessWidget {
  const _ProjectAction({
    required this.title,
    required this.onPress,
    this.primary = false,
    this.icon,
  });
  final String title;
  final VoidCallback onPress;
  final bool primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => kit.Pressable(
    label: title,
    onPress: onPress,
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: primary ? c.primary : c.brandSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 6,
        children: [
          if (icon != null) Icon(icon, size: 20, color: c.brand),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primary ? c.card : c.brand,
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
        PreviewText(policy.summary!),
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
  final List<({String url, String name, String? caption})> items;
  final double width;
  final bool caption;
  @override
  Widget build(BuildContext context) => SizedBox(
    height:
        width * 3 / 5 +
        (caption ? MediaQuery.textScalerOf(context).scale(48) + 4 : 0),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final x = items[index];
        return Semantics(
          button: true,
          label: x.name,
          child: kit.Pressable(
            onPress: () => isFileUrl(x.url)
                ? openInApp(context, x.url, x.name)
                : openGallery(
                    context,
                    [
                      for (final item in items.where(
                        (item) => !isFileUrl(item.url),
                      ))
                        (url: item.url, caption: item.caption),
                    ],
                    initialIndex: items
                        .where((item) => !isFileUrl(item.url))
                        .toList()
                        .indexOf(x),
                  ),
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
                  if (caption)
                    Expanded(
                      child: SingleChildScrollView(child: kit.Muted(x.name)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
