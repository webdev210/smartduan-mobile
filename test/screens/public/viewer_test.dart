// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:smartduan/api/errors.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:smartduan/screens/public/viewer.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../ui/detail_webview_fake.dart';

class TemporaryPath extends PathProviderPlatform {
  TemporaryPath(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

class LoopbackHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final declared in [true, false]) {
    test(
      'oversized download ${declared ? "header" : "stream"} aborts and removes temporary files',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'viewer-limit-test-',
        );
        final old = PathProviderPlatform.instance;
        PathProviderPlatform.instance = TemporaryPath(temp.path);
        addTearDown(() async {
          PathProviderPlatform.instance = old;
          await temp.delete(recursive: true);
        });
        var cancelled = false;
        var read = false;
        final stream = StreamController<Uint8List>(
          onListen: () => read = true,
          onCancel: () => cancelled = true,
        );
        // Deliberately never closes: crossing the limit must cancel immediately.
        stream.add(Uint8List.fromList([1, 2, 3]));
        stream.add(Uint8List.fromList([4, 5, 6]));
        final response = Response<ResponseBody>(
          requestOptions: RequestOptions(path: '/file.pdf'),
          headers: Headers.fromMap({
            if (declared) 'content-length': ['6'],
          }),
          data: ResponseBody(stream.stream, 200),
        );
        try {
          await expectLater(
            saveViewerFile(
              response,
              'https://example.vn/file.pdf',
              maxBytes: 4,
            ).timeout(const Duration(seconds: 2)),
            throwsA(
              isA<ApiError>().having(
                (e) => e.message,
                'message',
                'File quá lớn để mở trong ứng dụng.',
              ),
            ),
          );
          expect(cancelled, isTrue);
          expect(await temp.list().toList(), isEmpty);
          if (!declared) expect(read, isTrue);
        } finally {
          unawaited(stream.close());
        }
      },
    );
  }
  test('download accepts exactly the byte limit', () async {
    final temp = await Directory.systemTemp.createTemp('viewer-boundary-test-');
    final old = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TemporaryPath(temp.path);
    try {
      final path = await saveViewerFile(
        Response<ResponseBody>(
          requestOptions: RequestOptions(path: '/file.pdf'),
          headers: Headers.fromMap({
            'content-length': ['4'],
          }),
          data: ResponseBody.fromBytes([1, 2, 3, 4], 200),
        ),
        'https://example.vn/file.pdf',
        maxBytes: 4,
      );
      expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
    } finally {
      PathProviderPlatform.instance = old;
      await temp.delete(recursive: true);
    }
  });
  testWidgets('oversized file shows the Vietnamese error and retry', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [
        viewerFileProvider('https://example.vn/a.pdf').overrideWith((_) async {
          throw const ApiError(
            413,
            'file_too_large',
            'File quá lớn để mở trong ứng dụng.',
          );
        }),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: const ViewerScreen(url: 'https://example.vn/a.pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('File quá lớn để mở trong ứng dụng.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Mở file'), findsNothing);
  });
  test(
    'download filenames honor disposition and cannot escape the temp directory',
    () {
      expect(
        downloadFilename(
          'https://example.vn/download',
          'attachment; filename="brochure.pdf"',
        ),
        'brochure.pdf',
      );
      expect(
        downloadFilename(
          'https://example.vn/download',
          "attachment; filename*=UTF-8''T%C3%A0i%20li%E1%BB%87u.pdf",
        ),
        'Tài liệu.pdf',
      );
      expect(
        downloadFilename(
          'https://example.vn/download',
          'attachment; filename="../../evil.pdf"',
        ),
        'evil.pdf',
      );
      expect(
        downloadFilename(
          'https://example.vn/download',
          r'attachment; filename="..\..\evil.pdf"',
        ),
        'evil.pdf',
      );
      expect(
        downloadFilename('https://example.vn/a.pdf?token=secret', null),
        'a.pdf',
      );
      expect(downloadFilename('https://example.vn/', null), 'document');
      expect(downloadFilename('https://example.vn/CON', null), 'document');
    },
  );
  test(
    'viewer navigation separates Android downloads from normal page loads',
    () {
      expect(
        viewerNavigation('https://example.vn/a.pdf', true, android: true),
        'download',
      );
      expect(
        viewerNavigation('https://example.vn/a.pdf', false, android: true),
        'allow',
      );
      expect(
        viewerNavigation('https://example.vn/a.pdf', true, android: false),
        'allow',
      );
      expect(
        viewerNavigation('mailto:a@example.vn', true, android: true),
        'external',
      );
      expect(
        viewerNavigation('content://secret', false, android: true),
        'block',
      );
    },
  );
  test(
    'file download writes response bytes under temp with server filename and no auth',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final temp = await Directory.systemTemp.createTemp('detail-test-');
      final old = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TemporaryPath(temp.path);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? auth;
      var requests = 0;
      server.listen((request) async {
        requests++;
        auth = request.headers.value('authorization');
        request.response.headers.set(
          'content-disposition',
          'attachment; filename="../../brochure.pdf"',
        );
        request.response.add([37, 80, 68, 70]);
        await request.response.close();
      });
      final container = ProviderContainer.test();
      final provider = viewerFileProvider(
        'http://127.0.0.1:${server.port}/download',
      );
      final subscription = container.listen(provider, (_, _) {});
      try {
        final path = await container.read(provider.future);
        expect(path.startsWith(temp.path), isTrue);
        expect(path.endsWith('brochure.pdf'), isTrue);
        expect(await File(path).readAsBytes(), [37, 80, 68, 70]);
        expect(auth, isNull);
        expect(requests, 1);
      } finally {
        subscription.close();
        await server.close(force: true);
        PathProviderPlatform.instance = old;
        await temp.delete(recursive: true);
      }
    }, LoopbackHttp()),
  );
  testWidgets('Android file route shares downloaded file and can reopen it', (
    tester,
  ) async {
    final platform = DetailWebViewPlatform();
    WebViewPlatform.instance = platform;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        calls.add(call);
        return 'success';
      },
    );
    final container = ProviderContainer.test(
      overrides: [
        viewerFileProvider('https://example.vn/download')
            .overrideWith((_) async => '/tmp/brochure.pdf'),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: const ViewerScreen(
            url: 'https://example.vn/download',
            file: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.controllers, isEmpty);
    expect(
      find.text(
        'Đã tải file về máy. Chọn ứng dụng để xem (Drive, trình đọc PDF…).',
      ),
      findsOneWidget,
    );
    expect(calls, hasLength(1));
    expect((calls.single.arguments as Map)['paths'], ['/tmp/brochure.pdf']);
    await tester.tap(find.text('Mở hoặc chia sẻ tài liệu'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
  });
  testWidgets('Android top-level file link switches from WebView to download', (
    tester,
  ) async {
    final platform = DetailWebViewPlatform();
    WebViewPlatform.instance = platform;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (_) async => 'success',
    );
    final container = ProviderContainer.test(
      overrides: [
        viewerFileProvider('https://example.vn/a.pdf')
            .overrideWith((_) async => '/tmp/a.pdf'),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: const ViewerScreen(url: 'https://example.vn/'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      await platform.controllers.single.navigation!.navigate(
        'https://example.vn/a.pdf',
      ),
      NavigationDecision.prevent,
    );
    await tester.pumpAndSettle();
    expect(find.text('Mở hoặc chia sẻ tài liệu'), findsOneWidget);
  });
  testWidgets('failed file download exposes explicit retry', (tester) async {
    var calls = 0;
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        viewerFileProvider('https://example.vn/a.pdf').overrideWith((_) async {
          calls++;
          throw const SocketException('offline');
        }),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: const ViewerScreen(url: 'https://example.vn/a.pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
