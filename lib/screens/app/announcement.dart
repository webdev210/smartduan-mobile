import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/sales.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/post_body.dart';

class AnnouncementScreen extends ConsumerWidget {
  const AnnouncementScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Bảng tin')),
    body: Screen(
      children: [
        AsyncView(
          value: ref.watch(fetchAnnouncementProvider(id)),
          onRetry: () => ref.invalidate(fetchAnnouncementProvider(id)),
          builder: (a) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              H1(a.title),
              Muted(fmtDate(a.publishedAt, true)),
              PostBody(html: a.body),
            ],
          ),
        ),
      ],
    ),
  );
}
