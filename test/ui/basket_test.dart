import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/basket.dart';

void main() {
  const parent = 'https://smartduan.vn';
  const src =
      'https://rh.smartland.vn/?embed=1&parent=https%3A%2F%2Fsmartduan.vn&nonce=n1#sd_token=abc';
  test('extracts HTTPS origin without path query hash', () {
    expect(
      embedOrigin('https://rh-norton-park.smartland.vn/a/b?x=1#y'),
      'https://rh-norton-park.smartland.vn',
    );
  });
  test('reject non HTTPS origin', () {
    for (final u in ['http://rh.smartland.vn', 'javascript:alert(1)', null]) {
      expect(embedOrigin(u), isNull);
    }
  });
  test('iframe URL escaped and sandbox referrer preserved', () {
    final html = basketFrameHtml(src, 'https://rh.smartland.vn', 'n1');
    expect(
      html,
      contains(
        'src="https://rh.smartland.vn/?embed=1&amp;parent=https%3A%2F%2Fsmartduan.vn&amp;nonce=n1#sd_token=abc"',
      ),
    );
    expect(
      html,
      contains(
        'sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox"',
      ),
    );
    expect(html, contains('referrerpolicy="no-referrer"'));
  });
  test('bridge script checks origin and nonce before forwarding', () {
    final script = RegExp(r'<script>([\s\S]*)</script>')
        .firstMatch(basketFrameHtml(src, 'https://rh.smartland.vn', 'n1'))!
        .group(1)!;
    expect(
      script,
      contains('e.origin!==O||!d||d.nonce!==N||typeof d.type!=="string"'),
    );
    expect(script, contains('var O="https://rh.smartland.vn",N="n1";'));
    const guard =
        'if(e.origin!==O||!d||d.nonce!==N||typeof d.type!=="string")return;';
    final guardIndex = script.indexOf(guard);
    final postMessageIndex = script.indexOf('.postMessage(');
    expect(guardIndex, greaterThanOrEqualTo(0));
    expect(postMessageIndex, greaterThan(guardIndex));
  });
  test('untrusted strings cannot break script element', () {
    expect(
      basketFrameHtml(src, 'https://rh.smartland.vn', '</script><b>'),
      isNot(contains('</script><b>')),
    );
  });
  test('parent and about allowed', () {
    for (final u in [parent, '$parent/', 'about:blank']) {
      expect(frameNavigation(u, true, parent), 'allow');
    }
  });
  test('subframe allows http and blocks unknown schemes', () {
    expect(
      frameNavigation('https://rh.smartland.vn/can/12', false, parent),
      'allow',
    );
    expect(frameNavigation('intent://x#Intent;end', false, parent), 'block');
  });
  test('top frame opens external HTTP and tel; blocks unknown scheme', () {
    for (final u in ['$parent/du-an/x', 'https://zalo.me/123', 'tel:0909']) {
      expect(frameNavigation(u, true, parent), 'open');
    }
    expect(frameNavigation('intent://x#Intent;end', true, parent), 'block');
  });
}
