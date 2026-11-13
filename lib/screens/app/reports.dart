import 'package:material_ui/material_ui.dart' hide Card, SearchBar, Row;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/errors.dart';
import '../../api/reports.dart';
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/search.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<ReportsScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(sessionProvider).roles;
    final scope = scopeFor(roles, 'view_reports');
    final siteWide = scope == 'all' || scope == 'unit';
    final surveyOn = siteWide || scope == 'assigned';
    final viewsOn = roles.contains('superadmin');
    final inventory = ref.watch(fetchInventoryReportProvider);
    final attention = ref.watch(fetchAttentionProvider);
    final recent = ref.watch(fetchRecentActivityProvider(20));
    final updates = ref.watch(fetchInventoryUpdatesProvider);
    final active = ref.watch(fetchActiveSalesProvider);
    final bookings = bookingsEnabled
        ? ref.watch(fetchBookingsWeeklyProvider(8))
        : null;
    final survey = surveyOn ? ref.watch(fetchSurveyReportProvider) : null;
    final listings = listingsEnabled && siteWide
        ? ref.watch(fetchListingsReportProvider)
        : null;
    final views = viewsOn ? ref.watch(fetchProjectViewsProvider) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: Screen(
        onRefresh: () => Future.wait([
          ref.refresh(fetchInventoryReportProvider.future),
          ref.refresh(fetchAttentionProvider.future),
          ref.refresh(fetchRecentActivityProvider(20).future),
          ref.refresh(fetchInventoryUpdatesProvider.future),
          ref.refresh(fetchActiveSalesProvider.future),
          if (bookingsEnabled)
            ref.refresh(fetchBookingsWeeklyProvider(8).future),
          if (surveyOn) ref.refresh(fetchSurveyReportProvider.future),
          if (listingsEnabled && siteWide)
            ref.refresh(fetchListingsReportProvider.future),
          if (viewsOn) ref.refresh(fetchProjectViewsProvider.future),
        ]),
        children: [
          SearchBar(
            value: q,
            onChangeText: (v) => setState(() => q = v),
            placeholder: 'Tìm dự án, mã căn trong báo cáo…',
          ),
          _ReportBlock(
            title: 'Cần chú ý',
            value: attention,
            retry: () => ref.invalidate(fetchAttentionProvider),
            builder: (a) => [
              Row(
                label: 'Chính sách mới',
                value: dash(a.policiesNew?.count ?? 0),
              ),
              Row(
                label: 'Tiến độ thay đổi',
                value: dash(a.progressChanged?.count ?? 0),
              ),
            ],
          ),
          _ReportBlock(
            title: 'Tồn kho theo dự án',
            value: inventory,
            retry: () => ref.invalidate(fetchInventoryReportProvider),
            builder: (rows) {
              if (rows.isEmpty) {
                return [const Muted('Chưa có dự án trong phạm vi của bạn.')];
              }
              final found = smartFilter(rows, q, (r) => [r.project]);
              return found.isEmpty
                  ? [const Muted('Không có dòng nào khớp từ khoá.')]
                  : [
                      for (final r in found)
                        Row(
                          label: r.project,
                          value:
                              '${dash(r.counts['available'] ?? 0)} ${statusLabel['available']!.toLowerCase()} / ${dash(r.total)}',
                        ),
                    ];
            },
          ),
          _ReportBlock(
            title: 'Biến động gần đây',
            value: recent,
            retry: () => ref.invalidate(fetchRecentActivityProvider(20)),
            builder: (rows) {
              if (rows.isEmpty) return [const Muted('Chưa có thay đổi.')];
              final found = smartFilter(
                rows,
                q,
                (r) => [r.unitCode, r.project, r.changedByName],
              );
              return found.isEmpty
                  ? [const Muted('Không có dòng nào khớp từ khoá.')]
                  : [
                      for (final r in found)
                        Row(
                          label:
                              '${r.unitCode} · ${r.project} · ${r.oldValue != null && statusLabel.containsKey(r.oldValue) && statusLabel.containsKey(r.newValue) ? 'Trạng thái' : 'Thay đổi (chưa có tên trường)'}',
                          value:
                              '${statusLabel[r.oldValue] ?? r.oldValue ?? '—'} → ${statusLabel[r.newValue] ?? r.newValue ?? '—'}\n${fmtDate(r.changedAt, true)}${r.changedByName?.isNotEmpty == true ? ' · ${r.changedByName}' : ''}',
                        ),
                    ];
            },
          ),
          _ReportBlock(
            title: 'Cập nhật bảng hàng',
            value: updates,
            retry: () => ref.invalidate(fetchInventoryUpdatesProvider),
            builder: (u) => [
              Muted(
                '${fmtDate(u.from)} – ${fmtDate(u.to)} (${dash(u.days)} ngày)',
              ),
              for (final r in smartFilter(u.data, q, (r) => [r.project]))
                Row(
                  label: r.project,
                  value:
                      '${dash(r.daysWithUpdate)}/${dash(r.days)} ngày${r.compliancePct != null ? ' · ${dash(r.compliancePct)}%' : ''}',
                ),
            ],
          ),
          _ReportBlock(
            title: 'Sale hoạt động',
            value: active,
            retry: () => ref.invalidate(fetchActiveSalesProvider),
            builder: (a) => [
              Muted('${fmtDate(a.from)} – ${fmtDate(a.to)}'),
              for (final r in a.byRole)
                Row(label: roleName(r.role), value: dash(r.users)),
              for (final b in a.byBranch)
                Row(
                  label: b.branch ?? 'Chưa có chi nhánh',
                  value: dash(b.users),
                ),
            ],
          ),
          if (bookings != null)
            _ReportBlock(
              title: 'Giao dịch theo tuần',
              value: bookings,
              retry: () => ref.invalidate(fetchBookingsWeeklyProvider(8)),
              builder: (b) => [
                for (final w in b.data)
                  Row(
                    label: 'Tuần ${fmtDate(w.weekStart)}',
                    value:
                        '${dash(w.confirmed)} xác nhận / ${dash(w.declared)} khai báo',
                  ),
              ],
            ),
          if (survey != null)
            _ReportBlock(
              title: 'Khảo sát sale',
              value: survey,
              retry: () => ref.invalidate(fetchSurveyReportProvider),
              builder: (s) => [
                Row(
                  label: 'Phản hồi',
                  value: '${dash(s.responses)} (bỏ qua ${dash(s.dismissed)})',
                ),
                Row(label: 'Dễ dùng (1–5)', value: dash(s.avgEase)),
                Row(
                  label: 'Sẽ giới thiệu',
                  value: '${dash(s.referYes)} có / ${dash(s.referNo)} không',
                ),
                for (final m in s.missing) Muted('“${m.text}”'),
              ],
            ),
          if (listings != null)
            _ReportBlock(
              title: 'Tin đăng đã tạo',
              value: listings,
              retry: () => ref.invalidate(fetchListingsReportProvider),
              builder: (l) => [
                Row(label: 'Tổng', value: dash(l.total)),
                for (final u in l.byUser)
                  Row(
                    label: u.fullName ?? u.salesCode ?? '—',
                    value: dash(u.count),
                  ),
              ],
            ),
          if (views != null)
            _ReportBlock(
              title: 'Lượt xem trang dự án',
              value: views,
              retry: () => ref.invalidate(fetchProjectViewsProvider),
              builder: (rows) => [
                for (final r in smartFilter(
                  sumViewsByProject(rows),
                  q,
                  (r) => [r.project],
                ))
                  Row(
                    label: r.project,
                    value:
                        '${dash(r.views)} xem · ${dash(r.ctaClicks)} bấm · ${dash(r.leads)} liên hệ',
                  ),
              ],
            ),
          const Muted('Số liệu chi tiết, xuất file: xem trên web quản trị.'),
        ],
      ),
    );
  }
}

class _ReportBlock<T> extends StatefulWidget {
  const _ReportBlock({
    required this.title,
    required this.value,
    required this.retry,
    required this.builder,
  });
  final String title;
  final AsyncValue<T> value;
  final VoidCallback retry;
  final List<Widget> Function(T) builder;
  @override
  State<_ReportBlock<T>> createState() => _ReportBlockState<T>();
}

class _ReportBlockState<T> extends State<_ReportBlock<T>> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    if (widget.value.error case ApiError(status: 403 || 404)) {
      return const SizedBox.shrink();
    }
    return Section(
      title: widget.title,
      child: AsyncView(
        value: widget.value,
        onRetry: widget.retry,
        builder: (data) {
          final rows = widget.builder(data);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.length > 5)
                Muted(
                  '${rows.length} dòng · ${expanded ? 'Vuốt để xem tất cả' : 'Hiển thị 5 dòng đầu'}',
                ),
              if (expanded && rows.length > 5)
                SizedBox(
                  height: 360,
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) => rows[i],
                  ),
                )
              else
                ...rows.take(5),
              if (rows.length > 5)
                Button(
                  kind: 'link',
                  title: expanded ? 'Thu gọn' : 'Xem thêm (${rows.length - 5})',
                  onPress: () => setState(() => expanded = !expanded),
                ),
            ],
          );
        },
      ),
    );
  }
}
