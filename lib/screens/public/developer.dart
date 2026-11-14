import 'package:ionicons/ionicons.dart';

import '../../ui/network_image.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/public.dart';
import '../../ui/catalog.dart';
import '../../ui/in_app.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/project_card.dart';
import '../../ui/project_filter.dart';

class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  String query = '';
  int pageCount = 1;
  @override
  Widget build(BuildContext context) {
    final dev = ref.watch(fetchPublicDeveloperProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(title: Text(dev.asData?.value.name ?? 'Chủ đầu tư')),
      body: SafeArea(
        top: false,
        child: kit.Screen(
          slivers: [
            if (dev.asData?.value case final d?)
              _projects(d.id)
            else
              const SliverToBoxAdapter(child: SizedBox.shrink()),
          ],
          children: [
            kit.AsyncView(
              value: dev,
              onRetry: () =>
                  ref.invalidate(fetchPublicDeveloperProvider(widget.slug)),
              builder: (d) => kit.Card(
                children: [
                  Row(
                    spacing: 14,
                    children: [
                      if (mediaUrl(d.logoUrl) case final logo?)
                        AppNetworkImage(
                          logo,
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                          semanticLabel: 'Logo ${d.name}',
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 72,
                            height: 72,
                            child: Icon(Ionicons.businessOutline),
                          ),
                        ),
                      Expanded(child: kit.H1(d.name)),
                    ],
                  ),
                  if (d.badges.isNotEmpty)
                    kit.Chips(
                      children: [
                        for (final b in d.badges)
                          kit.Chip(
                            icon: Ionicons.ribbonOutline,
                            label: b,
                            informational: true,
                          ),
                      ],
                    ),
                  if (d.description case final description?)
                    kit.Body(description),
                  if (d.website case final website?)
                    kit.Button(
                      kind: 'link',
                      icon: Ionicons.globeOutline,
                      title: 'Website chủ đầu tư',
                      onPress: () => openInApp(context, website, d.name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projects(String id) {
    final provider = listPublicProjectsProvider(
      PublicFilters(developerId: id, perPage: 50),
    );
    final projects = ref.watch(provider);
    final more = [
      for (var page = 2; page <= pageCount; page++)
        listPublicProjectsProvider(
          PublicFilters(developerId: id, perPage: 50, page: page),
        ),
    ];
    final queries = [for (final p in more) ref.watch(p)];
    if (projects.asData?.value case final page?) {
      final loaded = <String, PublicProject>{
        for (final p in page.data) p.id: p,
        for (final q in queries)
          for (final p in q.asData?.value.data ?? <PublicProject>[]) p.id: p,
      }.values.toList();
      final rows = filterProjects(loaded, ProjectFilter(q: query), const {});
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: kit.Section(
                title: 'Dự án',
                eyebrow: '${page.total} dự án',
                children: [
                  if (loaded.length < page.total)
                    kit.Muted('Hiển thị ${loaded.length}/${page.total} dự án'),
                  if (loaded.length > 4)
                    kit.SearchBar(
                      value: query,
                      onChangeText: (s) => setState(() => query = s),
                      placeholder: 'Tìm trong ${loaded.length} dự án đã tải…',
                    ),
                  for (var i = 0; i < queries.length; i++)
                    if (queries[i].hasError)
                      kit.ErrorBox(
                        error: queries[i].error!,
                        onRetry: () => ref.invalidate(more[i]),
                      ),
                  if (queries.any((q) => q.isLoading)) const kit.Loading(),
                ],
              ),
            ),
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final p = rows[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ProjectCard(
                    p: p,
                    onPress: () => context.push(
                      '/cong-khai/${Uri.encodeComponent(p.code)}',
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (loaded.length < page.total &&
                      !queries.any((q) => q.isLoading || q.hasError) &&
                      (queries.isEmpty
                          ? page.data.isNotEmpty
                          : queries.last.asData?.value.data.isNotEmpty == true))
                    kit.Button(
                      title: 'Tải thêm',
                      kind: 'secondary',
                      onPress: () => setState(() => pageCount++),
                    ),
                  if (page.data.isEmpty)
                    const kit.Muted('Chưa có dự án công khai.')
                  else if (rows.isEmpty) ...[
                    const kit.Muted('Không có dự án nào khớp.'),
                    kit.Button(
                      title: 'Xoá từ khoá',
                      kind: 'link',
                      onPress: () => setState(() => query = ''),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return SliverToBoxAdapter(
      child: kit.AsyncView(
        value: projects,
        onRetry: () => ref.invalidate(provider),
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}
