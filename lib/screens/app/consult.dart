import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/errors.dart';
import '../../api/sales.dart';
import '../../ui/kit.dart' hide Row;

class ConsultScreen extends ConsumerStatefulWidget {
  const ConsultScreen({super.key, this.projectId, this.name});
  final String? projectId, name;
  @override
  ConsumerState<ConsultScreen> createState() => _ConsultState();
}

class _ConsultState extends ConsumerState<ConsultScreen> {
  String message = '';
  bool consent = false, busy = false, sent = false;
  Object? failure;
  bool get unknown =>
      failure is ApiError &&
      (failure as ApiError).code == 'lead_delivery_unknown';

  Future<void> submit() async {
    if (busy || sent || unknown || !consent) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await ref.read(submitConsultProvider)({
        'consent': true,
        if (widget.projectId != null) 'project_id': widget.projectId,
        if (message.trim().isNotEmpty) 'message': message.trim(),
      });
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yêu cầu tư vấn')),
    body: Screen(
      children: [
        if (widget.name != null) Muted('Dự án: ${widget.name}'),
        Field(
          label: 'Nội dung (tuỳ chọn, tối đa 2000 ký tự)',
          value: message,
          onChangeText: (v) => setState(() => message = v),
          maxLength: 2000,
          maxLines: 5,
        ),
        Row(
          spacing: 12,
          children: [
            Switch(
              value: consent,
              onChanged: (v) => setState(() => consent = v),
            ),
            const Expanded(child: Body('Tôi đồng ý để sàn liên hệ tư vấn')),
          ],
        ),
        if (sent)
          const Notice(
            tone: 'success',
            text: 'Đã gửi yêu cầu. Sàn sẽ liên hệ bạn sớm.',
          ),
        if (unknown)
          const Notice(
            tone: 'warn',
            text: 'Chưa chắc yêu cầu đã tới sàn. Đừng gửi lại ngay — gọi hotline để xác nhận.',
          )
        else if (failure != null)
          Notice(tone: 'error', text: errorMessage(failure)),
        Button(
          title: 'Gửi',
          loading: busy,
          disabled: !consent || sent || unknown,
          onPress: submit,
        ),
      ],
    ),
  );
}
