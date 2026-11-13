import 'package:ionicons/ionicons.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../api/auth.dart';
import '../../api/errors.dart';
import '../../auth/session.dart';
import '../../config.dart';
import '../../ui/basket.dart';
import '../../ui/in_app.dart';
import '../../ui/kit.dart' as kit;

// A command, not a query: opening/retrying must always mint one new ticket.
final mintBasketTokenProvider = Provider.autoDispose(
  (ref) => (String projectId, [bool presenting = false]) async {
    // Check on invocation; a command provider must not throw while rebuilding
    // as the signed-in screen is being removed during logout.
    if (ref.read(sessionProvider).status != SessionStatus.signedIn) {
      throw const ApiError(
        401,
        'unauthorized',
        'Phiên đã hết hạn, vui lòng đăng nhập lại',
      );
    }
    return AuthApi(ref.read(apiClientProvider))
        .basketToken(projectId, presenting);
  },
);

String? basketMintError(Object error) => switch (error) {
  ApiError(status: 403) => 'Bạn không có quyền xem rổ hàng này',
  ApiError(status: 404) => 'Không tìm thấy rổ hàng hoặc tính năng đã tắt',
  ApiError(status: 409) => 'Dự án chưa cấu hình rổ hàng',
  _ => null,
};

class BasketScreen extends ConsumerWidget {
  const BasketScreen({super.key, this.projectId, this.url});
  final String? projectId, url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 125,
          leading: TextButton.icon(
            icon: const Icon(Ionicons.chevronBack),
            label: const Text('Quay lại'),
            onPressed: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: const Text('Rổ hàng'),
        ),
        body: session.status != SessionStatus.signedIn
            ? const SizedBox.shrink()
            : _Basket(
                key: ObjectKey(session),
                projectId: projectId,
                url: url,
                mint: ref.watch(mintBasketTokenProvider),
              ),
      ),
    );
  }
}

// ponytail: basket alone needs a bridge; share this setup when PublicWebView
// gains bridge/cookie hooks in a milestone that owns that shared file.
class _Basket extends StatefulWidget {
  const _Basket({super.key, this.projectId, this.url, required this.mint});
  final String? projectId, url;
  final Future<Map<String, dynamic>> Function(String, [bool]) mint;
  @override
  State<_Basket> createState() => _BasketState();
}

class _BasketState extends State<_Basket> {
  static const parent = webUrl == '' ? 'https://smartduan.vn' : webUrl;
  WebViewController? controller;
  Timer? timer;
  int generation = 0;
  bool ready = false, retryable = true;
  String? error;
  bool get valid =>
      (widget.projectId?.isNotEmpty ?? false) &&
      embedOrigin(widget.url) != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_Basket oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.url != widget.url) {
      _load();
    }
  }

  bool _current(int ticket) => mounted && ticket == generation;

  void _fail(int ticket, String message, {bool canRetry = true}) {
    if (!_current(ticket)) return;
    timer?.cancel();
    setState(() {
      error = message;
      retryable = canRetry;
      controller = null;
    });
  }

  Future<void> _load() async {
    final ticket = ++generation;
    timer?.cancel();
    setState(() {
      error = null;
      ready = false;
      controller = null;
      retryable = true;
    });
    if (!valid) return;
    String token;
    try {
      final response = await widget.mint(widget.projectId!);
      token = switch (response) {
        {'token': final String value} when value.isNotEmpty => value,
        _ => throw const FormatException('Invalid basket ticket'),
      };
    } catch (e) {
      _fail(
        ticket,
        basketMintError(e) ?? errorMessage(e),
        canRetry: basketMintError(e) == null,
      );
      return;
    }
    if (!_current(ticket)) return;
    final nonce = List.generate(
      4,
      (_) => Random.secure().nextInt(1 << 32).toRadixString(36),
    ).join();
    try {
      final params = WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              allowsInlineMediaPlayback: true,
              mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
            )
          : const PlatformWebViewControllerCreationParams();
      final next = WebViewController.fromPlatformCreationParams(params);
      await next.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (next.platform case final AndroidWebViewController android) {
        await android.setAllowFileAccess(false);
        await android.setAllowContentAccess(false);
        await android.setMediaPlaybackRequiresUserGesture(false);
        final cookies =
            WebViewCookieManager().platform as AndroidWebViewCookieManager;
        await cookies.setAcceptThirdPartyCookies(android, true);
      }
      await next.addJavaScriptChannel(
        'ReactNativeWebView',
        onMessageReceived: (event) {
          if (!_current(ticket) || error != null) return;
          Object? message;
          try {
            message = jsonDecode(event.message);
          } on FormatException {
            return;
          }
          if (message is! Map<String, dynamic>) return;
          timer?.cancel();
          if (message['type'] == 'sd:ready') {
            setState(() => ready = true);
          } else {
            final text = message['message'];
            _fail(
              ticket,
              text is String &&
                      text.isNotEmpty &&
                      !text.contains(token) &&
                      !text.contains(Uri.encodeComponent(token))
                  ? text
                  : 'Rổ hàng từ chối phiên đăng nhập',
            );
          }
        },
      );
      await next.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (!_current(ticket) || error != null) {
              return NavigationDecision.prevent;
            }
            final verdict = frameNavigation(
              request.url,
              request.isMainFrame,
              parent,
            );
            if (verdict == 'open') {
              // Never forward the ticket into a route or an external application.
              if (!request.url.contains(token) &&
                  !request.url.contains(Uri.encodeComponent(token))) {
                openInApp(context, request.url);
              }
            }
            return verdict == 'allow'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame != false) {
              _fail(
                ticket,
                'Không tải được rổ hàng. Kiểm tra mạng rồi thử lại.',
              );
            }
          },
        ),
      );
      if (!_current(ticket)) return;
      timer = Timer(const Duration(seconds: 15), () {
        if (!ready && error == null) {
          _fail(ticket, 'Không nhúng được rổ hàng. Kiểm tra mạng rồi thử lại.');
        }
      });
      await next.loadHtmlString(
        basketFrameHtml(
          basketUrl(widget.url!, token, parent: parent, nonce: nonce),
          embedOrigin(widget.url)!,
          nonce,
        ),
        baseUrl: parent,
      );
      if (_current(ticket) && error == null) setState(() => controller = next);
    } catch (_) {
      _fail(ticket, 'Không tải được rổ hàng. Kiểm tra mạng rồi thử lại.');
    }
  }

  @override
  void dispose() {
    ++generation;
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!valid) {
      return const kit.Screen(
        children: [
          kit.Notice(tone: 'warn', text: 'Link rổ hàng không hợp lệ.'),
        ],
      );
    }
    if (error case final message?) {
      return kit.Screen(
        children: [
          kit.Notice(tone: 'error', text: message),
          if (retryable) kit.Button(title: 'Thử lại', onPress: _load),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Stack(
        children: [
          if (controller case final c?)
            Positioned.fill(child: WebViewWidget(controller: c)),
          if (!ready)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      kit.Loading(),
                      kit.Muted('Đang kết nối rổ hàng…'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
