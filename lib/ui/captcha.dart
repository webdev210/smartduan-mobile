import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../config.dart';
import 'kit.dart' show Button, Muted;
import 'turnstile.dart';

class Captcha extends StatefulWidget {
  const Captcha({super.key, required this.action, required this.onToken});
  final String action;
  final ValueChanged<String?> onToken;

  @override
  State<Captcha> createState() => _CaptchaState();
}

class _CaptchaState extends State<Captcha> {
  WebViewController? _controller;
  String? _failed;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(Captcha oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action) {
      widget.onToken(null);
      unawaited(_load());
    }
  }

  bool _current(int attempt) => mounted && attempt == _attempt;
  void _fail(int attempt, String message) {
    if (!_current(attempt)) return;
    setState(() => _failed = message);
    widget.onToken(null);
  }

  Future<void> _load() async {
    final attempt = ++_attempt;
    final page = captchaUrl(widget.action, webUrl);
    setState(() {
      _failed = null;
      _controller = null;
    });
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.enableZoom(false);
      await controller.setBackgroundColor(Colors.transparent);
      if (controller.platform case final AndroidWebViewController android) {
        await android.setAllowFileAccess(false);
        await android.setAllowContentAccess(false);
      }
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              captchaNavigation(request.url, request.isMainFrame, page)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (error) {
            if (error.isForMainFrame != false) {
              _fail(attempt, 'Không tải được trang xác minh.');
            }
          },
          onHttpError: (error) {
            if (error.request?.uri.removeFragment() ==
                Uri.parse(page).removeFragment()) {
              _fail(attempt, 'Không tải được trang xác minh.');
            }
          },
        ),
      );
      await controller.addJavaScriptChannel(
        'ReactNativeWebView',
        onMessageReceived: (message) async {
          if (!_current(attempt)) return;
          try {
            final currentUrl = await controller.currentUrl();
            if (!_current(attempt)) return;
            switch (captchaMessage(message.message, currentUrl, page)) {
              case CaptchaToken(:final token):
                setState(() => _failed = null);
                widget.onToken(token);
              case CaptchaError():
                _fail(attempt, 'Xác minh lỗi hoặc đã hết hạn.');
              case CaptchaIgnored():
                break;
            }
          } catch (_) {
            _fail(attempt, 'Không tải được trang xác minh.');
          }
        },
      );
      if (!_current(attempt)) return;
      await controller.loadRequest(Uri.parse(page));
      if (_current(attempt)) setState(() => _controller = controller);
    } catch (_) {
      _fail(attempt, 'Không tải được trang xác minh.');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      SizedBox(
        height: 150,
        child: _controller == null
            ? null
            : WebViewWidget(key: ValueKey(_attempt), controller: _controller!),
      ),
      if (_failed != null)
        Row(
          spacing: 8,
          children: [
            Expanded(child: Muted(_failed!)),
            Button(
              title: 'Xác minh lại',
              kind: 'link',
              size: 'sm',
              onPress: () => unawaited(_load()),
            ),
          ],
        ),
    ],
  );
}
