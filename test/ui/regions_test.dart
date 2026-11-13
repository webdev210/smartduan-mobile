import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/regions.dart';

void main() {
  const fixtures = <String, String>{
    "Hà Nội": "Miền Bắc",
    "Hải Phòng": "Miền Bắc",
    "Quảng Ninh": "Miền Bắc",
    "Bắc Giang": "Miền Bắc",
    "Bắc Kạn": "Miền Bắc",
    "Bắc Ninh": "Miền Bắc",
    "Cao Bằng": "Miền Bắc",
    "Điện Biên": "Miền Bắc",
    "Hà Giang": "Miền Bắc",
    "Hà Nam": "Miền Bắc",
    "Hải Dương": "Miền Bắc",
    "Hòa Bình": "Miền Bắc",
    "Hưng Yên": "Miền Bắc",
    "Lai Châu": "Miền Bắc",
    "Lạng Sơn": "Miền Bắc",
    "Lào Cai": "Miền Bắc",
    "Nam Định": "Miền Bắc",
    "Ninh Bình": "Miền Bắc",
    "Phú Thọ": "Miền Bắc",
    "Sơn La": "Miền Bắc",
    "Thái Bình": "Miền Bắc",
    "Thái Nguyên": "Miền Bắc",
    "Tuyên Quang": "Miền Bắc",
    "Vĩnh Phúc": "Miền Bắc",
    "Yên Bái": "Miền Bắc",
    "Thanh Hóa": "Miền Trung",
    "Nghệ An": "Miền Trung",
    "Hà Tĩnh": "Miền Trung",
    "Quảng Bình": "Miền Trung",
    "Quảng Trị": "Miền Trung",
    "Thừa Thiên Huế": "Miền Trung",
    "Huế": "Miền Trung",
    "Đà Nẵng": "Miền Trung",
    "Quảng Nam": "Miền Trung",
    "Quảng Ngãi": "Miền Trung",
    "Bình Định": "Miền Trung",
    "Phú Yên": "Miền Trung",
    "Khánh Hòa": "Miền Trung",
    "Ninh Thuận": "Miền Trung",
    "Bình Thuận": "Miền Trung",
    "Kon Tum": "Miền Trung",
    "Gia Lai": "Miền Trung",
    "Đắk Lắk": "Miền Trung",
    "Đắk Nông": "Miền Trung",
    "Lâm Đồng": "Miền Trung",
    "TP.HCM": "Miền Nam",
    "TPHCM": "Miền Nam",
    "TP HCM": "Miền Nam",
    "TP. HCM": "Miền Nam",
    "HCM": "Miền Nam",
    "TP. Hồ Chí Minh": "Miền Nam",
    "Hồ Chí Minh": "Miền Nam",
    "TP Hồ Chí Minh": "Miền Nam",
    "Bình Dương": "Miền Nam",
    "Bình Phước": "Miền Nam",
    "Đồng Nai": "Miền Nam",
    "Tây Ninh": "Miền Nam",
    "Bà Rịa - Vũng Tàu": "Miền Nam",
    "Bà Rịa – Vũng Tàu": "Miền Nam",
    "Long An": "Miền Nam",
    "Tiền Giang": "Miền Nam",
    "Bến Tre": "Miền Nam",
    "Trà Vinh": "Miền Nam",
    "Vĩnh Long": "Miền Nam",
    "Đồng Tháp": "Miền Nam",
    "An Giang": "Miền Nam",
    "Kiên Giang": "Miền Nam",
    "Cần Thơ": "Miền Nam",
    "Hậu Giang": "Miền Nam",
    "Sóc Trăng": "Miền Nam",
    "Bạc Liêu": "Miền Nam",
    "Cà Mau": "Miền Nam",
  };
  test(
    'all RN province spellings and case variants map to the same region',
    () {
      for (final MapEntry(:key, :value) in fixtures.entries) {
        expect(regionOf(key), value, reason: key);
        expect(regionOf(key.toLowerCase()), value, reason: key);
      }
    },
  );
  const decomposed = <String, String>{
    "Ha\u0300 No\u0323\u0302i": "Miền Bắc",
    "Ha\u0309i Pho\u0300ng": "Miền Bắc",
    "Qua\u0309ng Ninh": "Miền Bắc",
    "Ba\u0306\u0301c Giang": "Miền Bắc",
    "Ba\u0306\u0301c Ka\u0323n": "Miền Bắc",
    "Ba\u0306\u0301c Ninh": "Miền Bắc",
    "Cao Ba\u0306\u0300ng": "Miền Bắc",
    "\u0110ie\u0323\u0302n Bie\u0302n": "Miền Bắc",
    "Ha\u0300 Giang": "Miền Bắc",
    "Ha\u0300 Nam": "Miền Bắc",
    "Ha\u0309i Du\u031bo\u031bng": "Miền Bắc",
    "Ho\u0300a Bi\u0300nh": "Miền Bắc",
    "Hu\u031bng Ye\u0302n": "Miền Bắc",
    "Lai Cha\u0302u": "Miền Bắc",
    "La\u0323ng So\u031bn": "Miền Bắc",
    "La\u0300o Cai": "Miền Bắc",
    "Nam \u0110i\u0323nh": "Miền Bắc",
    "Ninh Bi\u0300nh": "Miền Bắc",
    "Phu\u0301 Tho\u0323": "Miền Bắc",
    "So\u031bn La": "Miền Bắc",
    "Tha\u0301i Bi\u0300nh": "Miền Bắc",
    "Tha\u0301i Nguye\u0302n": "Miền Bắc",
    "Tuye\u0302n Quang": "Miền Bắc",
    "Vi\u0303nh Phu\u0301c": "Miền Bắc",
    "Ye\u0302n Ba\u0301i": "Miền Bắc",
    "Thanh Ho\u0301a": "Miền Trung",
    "Nghe\u0323\u0302 An": "Miền Trung",
    "Ha\u0300 Ti\u0303nh": "Miền Trung",
    "Qua\u0309ng Bi\u0300nh": "Miền Trung",
    "Qua\u0309ng Tri\u0323": "Miền Trung",
    "Thu\u031b\u0300a Thie\u0302n Hue\u0302\u0301": "Miền Trung",
    "Hue\u0302\u0301": "Miền Trung",
    "\u0110a\u0300 Na\u0306\u0303ng": "Miền Trung",
    "Qua\u0309ng Nam": "Miền Trung",
    "Qua\u0309ng Nga\u0303i": "Miền Trung",
    "Bi\u0300nh \u0110i\u0323nh": "Miền Trung",
    "Phu\u0301 Ye\u0302n": "Miền Trung",
    "Kha\u0301nh Ho\u0300a": "Miền Trung",
    "Ninh Thua\u0323\u0302n": "Miền Trung",
    "Bi\u0300nh Thua\u0323\u0302n": "Miền Trung",
    "Kon Tum": "Miền Trung",
    "Gia Lai": "Miền Trung",
    "\u0110a\u0306\u0301k La\u0306\u0301k": "Miền Trung",
    "\u0110a\u0306\u0301k No\u0302ng": "Miền Trung",
    "La\u0302m \u0110o\u0302\u0300ng": "Miền Trung",
    "TP.HCM": "Miền Nam",
    "TPHCM": "Miền Nam",
    "TP HCM": "Miền Nam",
    "TP. HCM": "Miền Nam",
    "HCM": "Miền Nam",
    "TP. Ho\u0302\u0300 Chi\u0301 Minh": "Miền Nam",
    "Ho\u0302\u0300 Chi\u0301 Minh": "Miền Nam",
    "TP Ho\u0302\u0300 Chi\u0301 Minh": "Miền Nam",
    "Bi\u0300nh Du\u031bo\u031bng": "Miền Nam",
    "Bi\u0300nh Phu\u031bo\u031b\u0301c": "Miền Nam",
    "\u0110o\u0302\u0300ng Nai": "Miền Nam",
    "Ta\u0302y Ninh": "Miền Nam",
    "Ba\u0300 Ri\u0323a - Vu\u0303ng Ta\u0300u": "Miền Nam",
    "Ba\u0300 Ri\u0323a \u2013 Vu\u0303ng Ta\u0300u": "Miền Nam",
    "Long An": "Miền Nam",
    "Tie\u0302\u0300n Giang": "Miền Nam",
    "Be\u0302\u0301n Tre": "Miền Nam",
    "Tra\u0300 Vinh": "Miền Nam",
    "Vi\u0303nh Long": "Miền Nam",
    "\u0110o\u0302\u0300ng Tha\u0301p": "Miền Nam",
    "An Giang": "Miền Nam",
    "Kie\u0302n Giang": "Miền Nam",
    "Ca\u0302\u0300n Tho\u031b": "Miền Nam",
    "Ha\u0323\u0302u Giang": "Miền Nam",
    "So\u0301c Tra\u0306ng": "Miền Nam",
    "Ba\u0323c Lie\u0302u": "Miền Nam",
    "Ca\u0300 Mau": "Miền Nam",
  };
  test('decomposed Vietnamese matches NFC province spellings', () {
    for (final MapEntry(:key, :value) in decomposed.entries) {
      expect(regionOf(key), value, reason: key);
    }
  });
  test('normalization strips prefixes, folds whitespace and dash variants', () {
    expect(normalizeProvince('  Tỉnh   bình dương '), 'Bình Dương');
    expect(normalizeProvince('Thành phố Hồ Chí Minh'), 'TP.HCM');
    expect(normalizeProvince('TP. HCM'), 'TP.HCM');
    expect(normalizeProvince('bà rịa—vũng tàu'), 'Bà Rịa - Vũng Tàu');
    expect(normalizeProvince(null), '');
    expect(regionOf('unknown'), 'Khác');
    expect(regionOf(null), 'Khác');
  });
  test('region filtering is optional and rejects unknown region keys', () {
    expect(inRegion('Hà Nội'), true);
    expect(inRegion('Hà Nội', 'bac'), true);
    expect(inRegion('Hà Nội', 'nam'), false);
    expect(inRegion(null, 'bac'), false);
    expect(inRegion('Hà Nội', 'unknown'), false);
  });
}
