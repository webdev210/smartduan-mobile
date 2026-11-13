import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/format.dart';

void main() {
  group("fmtPrice", () {
    test("tỷ / triệu / thiếu giá", () {
      expect(fmtPrice("2100000000"), matches(r"^2[,.]1 tỷ$"));
      expect(fmtPrice("850000000"), matches(r"^850 tr$"));
      expect(fmtPrice(null), "—");
      expect(fmtPrice(null), "—");
      expect(fmtPrice("abc"), "—");
    });
  });

  group("fmtDate / dash", () {
    test("định dạng dd/mm/yyyy, chuỗi hỏng giữ nguyên", () {
      expect(fmtDate("2026-11-04T10:00:00"), "04/11/2026");
      expect(fmtDate("hỏng"), "hỏng");
      expect(fmtDate(null), "—");
      expect(dash(0), "0");
      expect(dash(""), "—");
    });
  });

  group("absoluteUrl (link tải tài liệu)", () {
    test(
      "ghép origin của API cho đường dẫn tương đối, giữ nguyên URL tuyệt đối",
      () {
        expect(
          absoluteUrl(
            "/api/v1/public/dl/tok",
            "http://192.168.1.20:4000/api/v1",
          ),
          "http://192.168.1.20:4000/api/v1/public/dl/tok",
        );
        expect(
          absoluteUrl("https://cdn.x/y", "http://h/api/v1"),
          "https://cdn.x/y",
        );
      },
    );
  });

  group("unitPriceLines (khung Giá của căn — backend 8478f6a: nhiều cột Sheet cho một loại giá)", () {
    test(
      "không có extra_prices: giá niêm yết luôn có, giá khác chỉ khi có số",
      () {
        expect(
          unitPriceLines({
            'price_list': "1",
            'price_loan': null,
            'price_early': "3",
          }),
          [
            {'field': "price_list", 'label': "Giá niêm yết", 'value': "1"},
            {
              'field': "price_early",
              'label': "Giá thanh toán sớm",
              'value': "3",
            },
          ],
        );
      },
    );

    test("loại giá có nhiều cột: liệt kê từng giá theo nhãn cột, đúng thứ tự; loại khác giữ một dòng", () {
      final got = unitPriceLines({
        'price_list': "10",
        'price_early': "8",
        'price_loan': "9",
        'extra_prices': [
          {'field': "price_early", 'label': "GIÁ TT SỚM 95%", 'value': "8"},
          {'field': "price_early", 'label': "GIÁ TT SỚM 70%", 'value': "8.5"},
        ],
      });
      expect(got, [
        {'field': "price_list", 'label': "Giá niêm yết", 'value': "10"},
        {'field': "price_loan", 'label': "Giá vay", 'value': "9"},
        {
          'field': "price_early",
          'label': "Giá thanh toán sớm",
          'prices': [
            {'label': "GIÁ TT SỚM 95%", 'value': "8"},
            {'label': "GIÁ TT SỚM 70%", 'value': "8.5"},
          ],
        },
      ]);
    });
  });

  group(
    "priceLabel (như thẻ dự án của web: \"Giá từ …\" hoặc \"Liên hệ\")",
    () {
      test("có giá → Giá từ; chưa công bố, 0 hoặc rác → Liên hệ", () {
        expect(priceLabel("2100000000"), "Giá từ 2,1 tỷ");
        expect(priceLabel(null), "Liên hệ");
        expect(priceLabel("0"), "Liên hệ");
        expect(priceLabel("abc"), "Liên hệ");
      });
    },
  );

  test('money, areas, missing and nonfinite display values', () {
    expect(fmtMoney(1234567.5), '1.234.568 đ');
    expect(fmtMoney(-1.5), '-1 đ');
    expect(fmtMoney(null), '—');
    expect(fmtMoney(double.infinity), '—');
    expect(fmtPrice('1234.5678'), '1.234,568');
    expect(fmtPrice('1005000000'), '1,01 tỷ');
    expect(fmtPrice('1250000'), '1,3 tr');
    expect(fmtPrice(''), '—');
    expect(fmtArea('75.5'), '75.5 m²');
    expect(fmtArea(null), '—');
    expect(fmtArea(''), '—');
    expect(dash(1.0), '1');
    expect(dash(null), '—');
  });
  test(
    'dates use Asia/Ho_Chi_Minh across day boundaries and explicit offsets',
    () {
      expect(fmtDate('2026-11-04T18:30:00Z', true), '01:30 05/11/2026');
      expect(fmtDate('2026-11-04T18:30:00+02:00', true), '23:30 04/11/2026');
      expect(fmtDate('2026-11-04T10:00:00', true), '10:00 04/11/2026');
      expect(fmtDate('2026-11-04'), '04/11/2026');
      expect(fmtDate(''), '—');
    },
  );
}
