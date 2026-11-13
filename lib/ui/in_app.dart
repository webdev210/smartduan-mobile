import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

bool isHttp(String? url) =>
    url != null && RegExp(r'^https?://', caseSensitive: false).hasMatch(url);
bool isFileUrl(String url) => RegExp(
  r'\.(pdf|docx?|xlsx?|pptx?|zip|rar)$',
  caseSensitive: false,
).hasMatch(url.split(RegExp(r'[?#]')).first);
num _number(Object? value) => switch (value) {
  null => 0,
  num n => n,
  bool b => b ? 1 : 0,
  String s => s.trim().isEmpty ? 0 : num.tryParse(s.trim()) ?? double.nan,
  _ => double.nan,
};
String _jsNumber(num n) =>
    n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
String mapEmbedUrl(Object? lat, Object? lng, [int zoom = 16]) {
  final y = _number(lat), x = _number(lng);
  if (lat == null ||
      lng == null ||
      !y.isFinite ||
      !x.isFinite ||
      y.abs() > 90 ||
      x.abs() > 180 ||
      (y == 0 && x == 0)) {
    return '';
  }
  return 'https://maps.google.com/maps?q=${_jsNumber(y)},${_jsNumber(x)}&z=$zoom&output=embed';
}

String policyNavigation(String url, bool isTopFrame) {
  if (url.startsWith('about:blank')) return 'allow';
  if (!isTopFrame) return 'block';
  return isHttp(url) ||
          RegExp(r'^(tel|mailto):', caseSensitive: false).hasMatch(url)
      ? 'open'
      : 'block';
}

/// Pure destination decision, shared by link handlers and their tests.
({String destination, String url, String? title, bool file}) inAppDestination(
  String url, [
  String? title,
  bool file = false,
]) => (
  destination: isHttp(url) ? 'viewer' : 'device',
  url: url,
  title: title,
  file: file,
);

Future<void> openInApp(
  BuildContext context,
  String url, [
  String? title,
  bool file = false,
]) async {
  final target = inAppDestination(url, title, file);
  try {
    switch (target.destination) {
      case 'viewer':
        await context.push(
          Uri(
            path: '/xem',
            queryParameters: {
              'url': url,
              'title': ?title,
              if (file) 'file': '1',
            },
          ).toString(),
        );
      case 'device':
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted) _launchFailure(context, url);
    }
  } catch (_) {
    if (context.mounted) _launchFailure(context, url);
  }
}

void _launchFailure(BuildContext context, String url) {
  if (Scaffold.maybeOf(context) == null) return;
  final uri = Uri.tryParse(url);
  final copyable =
      uri != null && {'tel', 'mailto', 'http', 'https'}.contains(uri.scheme);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: const Text('Không mở được liên kết. Vui lòng thử lại.'),
      action: copyable
          ? SnackBarAction(
              label: 'Sao chép',
              onPressed: () async {
                try {
                  await Clipboard.setData(
                    ClipboardData(
                      text: uri.scheme == 'tel' || uri.scheme == 'mailto'
                          ? uri.path
                          : url,
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('Đã sao chép')),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text('Không sao chép được. Vui lòng thử lại.'),
                      ),
                    );
                  }
                }
              },
            )
          : null,
    ),
  );
}
