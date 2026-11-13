import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/post_html.dart';

void main() {
  group("parsePostHtml — HTML bài viết (đã qua allowlist PostHtml của backend) → khối hiển thị", () {
    test("đoạn văn, tiêu đề, chữ đậm/nghiêng và liên kết", () {
      final blocks = parsePostHtml(
        '<p><em>Cập nhật ngày 20/10/2026</em></p>\n<h2>Phân khu Bạch Vân</h2>\n<p>Bạch Vân là <strong>Khu 1</strong> của <a href="https://smartproperty.vn/x/" rel="noopener">Vinhomes Hải Vân</a>.</p>',
      );
      expect(blocks, [
        {
          'type': "p",
          'spans': [
            {'text': "Cập nhật ngày 20/10/2026", 'italic': true},
          ],
        },
        {
          'type': "h2",
          'spans': [
            {'text': "Phân khu Bạch Vân"},
          ],
        },
        {
          'type': "p",
          'spans': [
            {'text': "Bạch Vân là "},
            {'text': "Khu 1", 'bold': true},
            {'text': " của "},
            {'text': "Vinhomes Hải Vân", 'href': "https://smartproperty.vn/x/"},
            {'text': "."},
          ],
        },
      ]);
    });

    test("figure: ảnh kèm chú thích", () {
      final blocks = parsePostHtml(
        '<figure><img src="https://x/a.jpg" alt="Phối cảnh" /><figcaption>Nguồn: CĐT.</figcaption></figure>',
      );
      expect(blocks, [
        {
          'type': "img",
          'src': "https://x/a.jpg",
          'alt': "Phối cảnh",
          'caption': "Nguồn: CĐT.",
        },
      ]);
    });

    test("danh sách, trích dẫn, giải mã ký tự HTML, gộp khoảng trắng, bỏ đoạn rỗng", () {
      final blocks = parsePostHtml(
        "<ul><li>Giá &amp; chính sách</li><li>Tiến   độ\n xây</li></ul><blockquote><p>“Câu nói” &#8211; ai đó</p></blockquote><p>&nbsp;</p><hr/>",
      );
      expect(blocks, [
        {
          'type': "list",
          'ordered': false,
          'items': [
            [
              {'text': "Giá & chính sách"},
            ],
            [
              {'text': "Tiến độ xây"},
            ],
          ],
        },
        {
          'type': "quote",
          'spans': [
            {'text': "“Câu nói” – ai đó"},
          ],
        },
        {'type': "hr"},
      ]);
    });

    test("link không phải http(s) chỉ còn chữ; ảnh không phải http(s) bị bỏ; br thành xuống dòng", () {
      final blocks = parsePostHtml(
        '<p>Xem <a href="/du-an/X">dự án</a><br>dòng 2</p><img src="data:x">',
      );
      expect(blocks, [
        {
          'type': "p",
          'spans': [
            {'text': "Xem dự án\ndòng 2"},
          ],
        },
      ]);
    });

    test("chữ nằm ngoài thẻ khối vẫn thành đoạn văn; rỗng → []", () {
      expect(parsePostHtml("Chỉ có chữ"), [
        {
          'type': "p",
          'spans': [
            {'text': "Chỉ có chữ"},
          ],
        },
      ]);
      expect(parsePostHtml(""), isEmpty);
    });
  });

  group("plainText", () {
    test("bỏ thẻ, giải mã, gộp khoảng trắng", () {
      expect(plainText("<p>A &amp; <b>B</b></p>\n<p>C</p>"), "A & B C");
    });
  });
}
