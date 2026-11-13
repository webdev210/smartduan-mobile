import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
// Platform boundary supplied by the installed webview_flutter dependency.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  final controllers = <FakeWebController>[];
  FakeWebController get latest => controllers.last;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeWebController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => FakeNavigationDelegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeWebWidget(params);
}

class FakeWebController extends PlatformWebViewController {
  FakeWebController(super.params) : super.implementation();
  String? url;
  final loads = <String>[];
  late FakeNavigationDelegate delegate;
  late JavaScriptChannelParams channel;
  JavaScriptMode? javaScriptMode;
  bool? zoom;
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    url = params.uri.toString();
    loads.add(url!);
  }

  @override
  Future<String?> currentUrl() async => url;
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    delegate = handler as FakeNavigationDelegate;
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {
    javaScriptMode = mode;
  }

  @override
  Future<void> enableZoom(bool enabled) async {
    zoom = enabled;
  }

  @override
  Future<void> setBackgroundColor(Color color) async {}
  void message(String data) =>
      channel.onMessageReceived(JavaScriptMessage(message: data));
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();
  late NavigationRequestCallback navigate;
  late WebResourceErrorCallback error;
  late HttpResponseErrorCallback httpError;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    navigate = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    error = callback;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {
    httpError = callback;
  }
}

class FakeWebWidget extends PlatformWebViewWidget {
  FakeWebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
