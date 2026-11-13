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
import '../../ui/theme.dart' as c;

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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: c.brandSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              b,
                              style: const TextStyle(
                                color: c.brand,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (d.description case final description?)
                    kit.Body(description),
                  if (d.website case final website?)
                    kit.Button(
                      kind: 'link',
                      icon: Ionicons.globeOutline,
                      title: website,
                      onPress: () => openInApp(context, website, d.name),
                    ),
                ],
              ),
            ),
            if (dev.asData?.value case final d?) _projects(d.id),
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
    return kit.Section(
      title: 'Dự án',
      eyebrow: projects.asData == null
          ? null
          : '${projects.asData!.value.total} dự án',
      child: kit.AsyncView(
        value: projects,
        onRetry: () => ref.invalidate(provider),
        builder: (page) {
          final loaded = <String, PublicProject>{
            for (final p in page.data) p.id: p,
            for (final q in queries)
              for (final p in q.asData?.value.data ?? <PublicProject>[])
                p.id: p,
          }.values.toList();
          final rows = filterProjects(
            loaded,
            ProjectFilter(q: query),
            const {},
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
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
              for (final p in rows)
                ProjectCard(
                  p: Browsable(
                    id: p.id,
                    name: p.name,
                    status: p.status,
                    code: p.code,
                    coverUrl: p.coverUrl,
                    province: p.province,
                    district: p.district,
                    priceFrom: p.priceFrom,
                    projectType: p.projectType,
                    hasTour360: p.hasTour360,
                    activity7d: p.activity7d,
                  ),
                  onPress: () =>
                      context.push('/cong-khai/${Uri.encodeComponent(p.code)}'),
                ),
              if (page.data.isEmpty)
                const kit.Muted('Chưa có dự án công khai.')
              else if (rows.isEmpty)
                kit.Empty(
                  icon: Ionicons.searchOutline,
                  text: 'Không có dự án nào khớp.',
                  action: (
                    label: 'Xoá từ khoá',
                    onPress: () => setState(() => query = ''),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
