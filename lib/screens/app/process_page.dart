import 'package:ionicons/ionicons.dart';

import '../../ui/network_image.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/errors.dart';
import '../../api/sales.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;

class ProcessPageScreen extends ConsumerStatefulWidget {
  const ProcessPageScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<ProcessPageScreen> createState() => _ProcessPageState();
}

class _ProcessPageState extends ConsumerState<ProcessPageScreen> {
  bool busy = false;
  Object? failure;
  Future<void> ask() async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await ref.read(requestProcessAccessProvider)(widget.slug);
      if (mounted) {
        ref.invalidate(fetchProcessPageProvider(widget.slug));
        ref.invalidate(fetchProcessPagesProvider);
      }
    } catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(fetchProcessPageProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(title: Text(q.value?.title ?? 'Quy trình')),
      body: Screen(
        children: [
          AsyncView(
            value: q,
            onRetry: () =>
                ref.invalidate(fetchProcessPageProvider(widget.slug)),
            builder: (p) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                if (p.coverUrl != null && p.coverUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AppNetworkImage(
                      p.coverUrl!,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 180,
                        child: Icon(Ionicons.imageOutline),
                      ),
                    ),
                  ),
                H1(p.title),
                Muted(
                  '${p.projectName != null ? '${p.projectName} · ' : ''}Cập nhật ${fmtDate(p.updatedAt, true)}',
                ),
                if (p.summary?.isNotEmpty == true) Body(p.summary!),
                if (p.status == 'pending')
                  const Notice(
                    tone: 'warn',
                    text: 'Đang chờ duyệt — quản trị sẽ mở quyền xem trang này cho bạn.',
                  ),
                if (p.status != 'approved' && p.status != 'pending') ...[
                  const Notice(
                    tone: 'warn',
                    text: 'Trang này chỉ dành cho nhân sự được duyệt.',
                  ),
                  Button(
                    title: 'Xin quyền truy cập',
                    loading: busy,
                    onPress: ask,
                  ),
                  if (failure != null)
                    Notice(tone: 'error', text: errorMessage(failure)),
                ],
                const Notice(
                  text:
                      'Xem nội dung đầy đủ của trang này trên web Smart Dự Án.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
