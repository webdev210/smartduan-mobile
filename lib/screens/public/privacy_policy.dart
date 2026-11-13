import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/public.dart';
import '../../config.dart';
import '../../ui/in_app.dart';
import '../../ui/kit.dart' show AsyncView;
import '../../ui/tour_frame.dart';
import '../../ui/theme.dart' as c;

String policyHtml(String body) =>
    '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><base href="${webUrl.isEmpty ? 'https://smartduan.vn' : webUrl}/chinh-sach-bao-mat/toan-van">
<style>body{font-family:-apple-system,Roboto,sans-serif;font-size:15px;line-height:1.6;color:#18181b;padding:4px 16px 32px;margin:0}h1{font-size:22px;line-height:1.3}h2{font-size:18px;margin-top:24px}h3{font-size:16px}a{color:#${(c.link.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')};text-decoration:underline}table{border-collapse:collapse;width:100%;font-size:13px;display:block;overflow-x:auto}td,th{border:1px solid #e4e4e7;padding:6px;vertical-align:top;text-align:left}</style>
</head><body>$body</body></html>''';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(fetchFullPolicyProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(policy.asData?.value.title ?? 'Chính sách bảo mật'),
      ),
      body: SafeArea(
        top: false,
        child: AsyncView(
          value: policy,
          onRetry: () => ref.invalidate(fetchFullPolicyProvider),
          builder: (p) => PublicWebView(
            html: policyHtml(p.body),
            title: p.title ?? 'Chính sách bảo mật',
            javascript: false,
            navigation: policyNavigation,
          ),
        ),
      ),
    );
  }
}
