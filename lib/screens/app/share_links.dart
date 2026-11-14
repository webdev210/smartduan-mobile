import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/errors.dart';
import '../../api/projects.dart';
import '../../auth/session.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/theme.dart' as c;

bool shareLinkIsDead(ShareLink link, [DateTime? now]) {
  final raw = link.expiresAt ?? '';
  // JavaScript interprets ISO date-only strings as UTC, unlike DateTime.parse.
  final expiry = DateTime.tryParse(
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw) ? '${raw}T00:00:00Z' : raw,
  );
  return (link.revokedAt?.isNotEmpty ?? false) ||
      (expiry?.isBefore(now ?? DateTime.now()) ?? false);
}

final sendShareLinkProvider = Provider(
  (ref) => (String message, Rect origin) async {
    await SharePlus.instance.share(
      ShareParams(text: message, sharePositionOrigin: origin),
    );
  },
);

class ShareLinksScreen extends ConsumerStatefulWidget {
  const ShareLinksScreen({
    super.key,
    required this.projectId,
    this.name,
    this.blockId,
  });
  final String projectId;
  final String? name, blockId;
  @override
  ConsumerState<ShareLinksScreen> createState() => _ShareLinksScreenState();
}

class _ShareLinksScreenState extends ConsumerState<ShareLinksScreen> {
  String only = 'all';
  bool creating = false, revoking = false;
  Object? error;
  String? copied;
  ShareLink? created;
  bool shareFailed = false;
  Timer? _copyTimer;
  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _send(ShareLink link) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    await ref.read(sendShareLinkProvider)(
      '${widget.name?.isNotEmpty == true ? '${widget.name}: ' : ''}${shareUrl(link)}',
      origin,
    );
  }

  Future<void> _create() async {
    if (creating) return;
    final session = ref.read(sessionProvider);
    setState(() {
      creating = true;
      error = null;
    });
    try {
      final link = await ref.read(createShareLinkProvider)(
        widget.projectId,
        widget.blockId,
      );
      if (!mounted || !identical(session, ref.read(sessionProvider))) return;
      setState(() {
        created = link;
        shareFailed = false;
        only = 'all';
      });
      ref.invalidate(fetchShareLinksProvider(widget.projectId));
      try {
        await _send(link);
      } catch (_) {
        if (mounted && identical(session, ref.read(sessionProvider))) {
          setState(() => shareFailed = true);
        }
      }
    } catch (e) {
      if (mounted && identical(session, ref.read(sessionProvider))) {
        setState(() => error = e);
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> _revoke(ShareLink link) async {
    if (revoking) return;
    final session = ref.read(sessionProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Thu hồi link?'),
        content: const Text('Khách đang giữ link này sẽ không mở được nữa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        !identical(session, ref.read(sessionProvider))) {
      return;
    }
    setState(() {
      revoking = true;
      error = null;
    });
    try {
      await ref.read(revokeShareLinkProvider)(link.id);
      if (mounted && identical(session, ref.read(sessionProvider))) {
        ref.invalidate(fetchShareLinksProvider(widget.projectId));
      }
    } catch (e) {
      if (mounted && identical(session, ref.read(sessionProvider))) {
        setState(() => error = e);
      }
    } finally {
      if (mounted) setState(() => revoking = false);
    }
  }

  Future<void> _resend(ShareLink link) async {
    try {
      await _send(link);
      if (mounted) setState(() => shareFailed = false);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _copy(ShareLink link) async {
    try {
      await Clipboard.setData(ClipboardData(text: shareUrl(link)));
      if (!mounted) return;
      _copyTimer?.cancel();
      setState(() => copied = link.id);
      _copyTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => copied = null);
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = fetchShareLinksProvider(widget.projectId);
    final links = ref.watch(provider);
    final all = [
      if (created != null &&
          !(links.value ?? <ShareLink>[]).any((l) => l.id == created!.id))
        created!,
      ...?links.value,
    ];
    final latest = all
        .where((l) => !shareLinkIsDead(l))
        .fold<ShareLink?>(
          null,
          (a, b) =>
              a == null || b.insertedAt.compareTo(a.insertedAt) > 0 ? b : a,
        );
    final filtered = all
        .where(
          (link) => only == 'all' || shareLinkIsDead(link) == (only == 'dead'),
        )
        .toList();
    ref.listen(sessionProvider, (_, _) {
      setState(() {
        error = null;
        created = null;
        shareFailed = false;
      });
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.name?.isNotEmpty == true
              ? 'Chia sẻ · ${widget.name}'
              : 'Chia sẻ cho khách',
        ),
      ),
      body: kit.Screen(
        onRefresh: () => ref.refresh(provider.future),
        slivers: [
          if (filtered.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, i) => _linkCard(filtered[i]),
              ),
            ),
        ],
        children: [
          const kit.Muted(
            'Khách mở link trên trình duyệt, xem bảng hàng với giá làm tròn và để lại liên hệ cho bạn.',
          ),
          if (latest != null)
            kit.Button(
              title: 'Gửi lại link đang dùng',
              icon: Ionicons.shareSocialOutline,
              onPress: () => _resend(latest),
            ),
          kit.Button(
            kind: latest == null ? 'primary' : 'secondary',
            icon: Ionicons.shareSocialOutline,
            title: 'Tạo link mới và gửi',
            loading: creating,
            onPress: _create,
          ),
          if (shareFailed)
            const kit.Notice(
              tone: 'warn',
              text: 'Đã tạo link; chưa mở được chia sẻ. Bạn có thể gửi lại hoặc sao chép link bên dưới.',
            ),
          if (error != null)
            kit.Notice(tone: 'error', text: errorMessage(error)),
          kit.AsyncView(
            value: links,
            onRetry: () => ref.invalidate(provider),
            builder: (list) {
              if (list.isEmpty) {
                return created != null
                    ? const SizedBox.shrink()
                    : const kit.Empty(
                        icon: Ionicons.shareSocialOutline,
                        text: 'Chưa có link chia sẻ nào.',
                      );
              }
              final ended = list.where(shareLinkIsDead).length;
              final rows = list.where(
                (link) =>
                    only == 'all' || shareLinkIsDead(link) == (only == 'dead'),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  kit.Segmented(
                    value: only,
                    onChange: (s) => setState(() => only = s),
                    options: [
                      (key: 'all', label: 'Tất cả', count: list.length),
                      (
                        key: 'live',
                        label: 'Còn hiệu lực',
                        count: list.length - ended,
                      ),
                      (key: 'dead', label: 'Đã hết', count: ended),
                    ],
                  ),
                  if (rows.isEmpty)
                    kit.Empty(
                      icon: Ionicons.linkOutline,
                      text: only == 'live'
                          ? 'Không còn link nào hiệu lực. Tạo link mới để gửi khách.'
                          : 'Chưa có link nào hết hạn hay bị thu hồi.',
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _linkCard(ShareLink link) => kit.Card(
    key: ValueKey(link.id),
    children: [
      kit.Pill(
        soft: true,
        label: link.revokedAt?.isNotEmpty == true
            ? 'Đã thu hồi'
            : shareLinkIsDead(link)
            ? 'Hết hạn'
            : 'Còn hiệu lực',
        color: shareLinkIsDead(link) ? c.muted : c.success,
      ),
      kit.Row(label: 'Tạo lúc', value: fmtDate(link.insertedAt, true)),
      kit.Row(
        label: 'Hết hạn',
        value: link.revokedAt?.isNotEmpty == true
            ? 'Đã thu hồi'
            : fmtDate(link.expiresAt, true),
      ),
      kit.Row(
        label: 'Lượt xem · liên hệ',
        value: '${link.viewCount} · ${link.leadCount}',
      ),
      if (link.createdByName?.isNotEmpty == true)
        kit.Row(label: 'Người tạo', value: link.createdByName!),
      if (!shareLinkIsDead(link)) ...[
        kit.Button(
          kind: 'secondary',
          title: 'Gửi lại link',
          onPress: () => _resend(link),
        ),
        kit.Button(
          kind: 'link',
          title: 'Sao chép link',
          icon: copied == link.id ? Ionicons.checkmark : null,
          onPress: () => _copy(link),
        ),
        kit.Button(
          kind: 'danger',
          title: 'Thu hồi',
          disabled: revoking,
          onPress: () => _revoke(link),
        ),
      ],
    ],
  );
}
