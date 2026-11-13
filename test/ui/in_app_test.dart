import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:smartduan/ui/in_app.dart';

void main() {
  testWidgets(
    'http links push viewer with correctly encoded title and file flag',
    (tester) async {
      const url = 'https://x.vn/a?x=1&y=2#lead';
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => TextButton(
              onPressed: () {
                openInApp(context, url, 'Tài liệu', true);
              },
              child: const Text('Open'),
            ),
          ),
          GoRoute(
            path: '/xem',
            builder: (_, state) => Text('${state.uri.queryParameters}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters, {
        'url': url,
        'title': 'Tài liệu',
        'file': '1',
      });
      expect(router.canPop(), true);
    },
  );
  testWidgets(
    'device links use external launcher and platform failures are swallowed',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        throw PlatformException(code: 'unavailable');
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      await openInApp(context, 'tel:1900');
      expect(calls.single.method, 'launch');
      expect(
        (calls.single.arguments as Map<Object?, Object?>)['url'],
        'tel:1900',
      );
      await openInApp(context, 'zalo://chat');
      expect(calls, hasLength(2));
      expect(
        (calls.last.arguments as Map<Object?, Object?>)['useWebView'],
        false,
      );
    },
  );
  test('http opens viewer with title and explicit download flag', () {
    expect(
      inAppDestination(
        'https://dev.smartduan.vn/du-an/abc#lead',
        'Nhận tư vấn',
      ),
      (
        destination: 'viewer',
        url: 'https://dev.smartduan.vn/du-an/abc#lead',
        title: 'Nhận tư vấn',
        file: false,
      ),
    );
    expect(
      inAppDestination(
        'https://x.vn/api/v1/public/dl/tok',
        'Tài liệu',
        true,
      ).file,
      true,
    );
  });
  test('tel and mailto go to device', () {
    for (final u in ['tel:0909123456', 'mailto:a@x.vn']) {
      expect(inAppDestination(u).destination, 'device');
      expect(inAppDestination(u).url, u);
    }
  });
  test('recognizes file extensions ignoring query and fragment', () {
    expect(isFileUrl('https://s3.vn/a/CSBH%20T11.PDF?X-Amz-Signature=1'), true);
    expect(isFileUrl('https://x.vn/bang-gia.xlsx#p'), true);
    expect(isFileUrl('https://x.vn/du-an/pdf-guide'), false);
    expect(isFileUrl('https://x.vn/anh.jpg'), false);
  });
  test('decimal coordinates create map embed', () {
    expect(
      mapEmbedUrl('10.7769', '106.7009'),
      'https://maps.google.com/maps?q=10.7769,106.7009&z=16&output=embed',
    );
  });
  test('missing invalid out of range or zero coordinates rejected', () {
    for (final coords in [
      (null, '106'),
      ('abc', '106'),
      ('91', '106'),
      ('0', '0'),
      ('10', '181'),
    ]) {
      expect(mapEmbedUrl(coords.$1, coords.$2), '');
    }
  });
  test('policy loads original document only', () {
    expect(policyNavigation('about:blank', true), 'allow');
  });
  test(
    'policy main frame opens http tel mailto and blocks unknown schemes',
    () {
      for (final u in [
        'https://smartduan.vn/lien-he',
        'tel:19001234',
        'mailto:a@x.vn',
      ]) {
        expect(policyNavigation(u, true), 'open');
      }
      expect(policyNavigation('intent://x#Intent;end', true), 'block');
    },
  );
  test('policy subframes cannot open links', () {
    expect(policyNavigation('https://evil.example/', false), 'block');
  });
}
