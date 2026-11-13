import 'package:unorm_dart/unorm_dart.dart' as unorm;

const _bac = [
  "Hà Nội",
  "Hải Phòng",
  "Quảng Ninh",
  "Bắc Giang",
  "Bắc Kạn",
  "Bắc Ninh",
  "Cao Bằng",
  "Điện Biên",
  "Hà Giang",
  "Hà Nam",
  "Hải Dương",
  "Hòa Bình",
  "Hưng Yên",
  "Lai Châu",
  "Lạng Sơn",
  "Lào Cai",
  "Nam Định",
  "Ninh Bình",
  "Phú Thọ",
  "Sơn La",
  "Thái Bình",
  "Thái Nguyên",
  "Tuyên Quang",
  "Vĩnh Phúc",
  "Yên Bái",
];

const _trung = [
  "Thanh Hóa",
  "Nghệ An",
  "Hà Tĩnh",
  "Quảng Bình",
  "Quảng Trị",
  "Thừa Thiên Huế",
  "Huế",
  "Đà Nẵng",
  "Quảng Nam",
  "Quảng Ngãi",
  "Bình Định",
  "Phú Yên",
  "Khánh Hòa",
  "Ninh Thuận",
  "Bình Thuận",
  "Kon Tum",
  "Gia Lai",
  "Đắk Lắk",
  "Đắk Nông",
  "Lâm Đồng",
];

const _nam = [
  "TP.HCM",
  "TPHCM",
  "TP HCM",
  "TP. HCM",
  "HCM",
  "TP. Hồ Chí Minh",
  "Hồ Chí Minh",
  "TP Hồ Chí Minh",
  "Bình Dương",
  "Bình Phước",
  "Đồng Nai",
  "Tây Ninh",
  "Bà Rịa - Vũng Tàu",
  "Bà Rịa – Vũng Tàu",
  "Long An",
  "Tiền Giang",
  "Bến Tre",
  "Trà Vinh",
  "Vĩnh Long",
  "Đồng Tháp",
  "An Giang",
  "Kiên Giang",
  "Cần Thơ",
  "Hậu Giang",
  "Sóc Trăng",
  "Bạc Liêu",
  "Cà Mau",
];

final _provinces = <String, String>{
  for (final province in _bac) province: "Miền Bắc",
  for (final province in _trung) province: "Miền Trung",
  for (final province in _nam) province: "Miền Nam",
};

String normalizeProvince(String? value) {
  final name = unorm
      .nfc(value ?? '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s*[–—-]\s*'), ' - ');
  final bare = name
      .replaceFirst(
        RegExp(r'^(?:thành phố|tỉnh|tp\.?)\s*', caseSensitive: false),
        '',
      )
      .trim();
  final lower = bare.toLowerCase();
  if (['hcm', 'hồ chí minh', 'hochiminh'].contains(lower)) return 'TP.HCM';
  for (final key in _provinces.keys) {
    if (key.toLowerCase() == lower) return key;
  }
  return bare;
}

String regionOf(String? province) =>
    _provinces[normalizeProvince(province)] ?? 'Khác';
const regions = [
  (key: 'bac', label: 'Miền Bắc'),
  (key: 'trung', label: 'Miền Trung'),
  (key: 'nam', label: 'Miền Nam'),
];
bool inRegion(String? province, [String? key]) =>
    key == null ||
    key.isEmpty ||
    regions.any((r) => r.key == key && r.label == regionOf(province));
