import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/overview.dart';

void main() {
  test('real Beachtro data separates summary specs source and hides crawler fields', () {
    final o = parseOverview({
      'Loại hình': 'Studio · 1BR, 1BR+ · 2BR, 2BR+ · 3BR, 3BR+',
      'description': 'Beachtro Tower: 1.785 căn hộ sở hữu lâu dài trong đại đô thị Blanca City, Vũng Tàu.',
      'handover': '2028',
      'location': {'geocoded': 'nominatim', 'precision': 'locality'},
      'phap_ly': 'Sở hữu lâu dài',
      'quy_mo': '4 tòa tháp ·',
      'so_can': 1785,
      'source_url': 'https://smartrealtors.vn/beachtro-tower-blanca-city/',
      'researched_at': '2026-10-01',
    });
    expect(
      o.summary,
      'Beachtro Tower: 1.785 căn hộ sở hữu lâu dài trong đại đô thị Blanca City, Vũng Tàu.',
    );
    expect(o.specs, [
      (
        key: 'Loại hình',
        label: 'Loại hình',
        value: 'Studio · 1BR, 1BR+ · 2BR, 2BR+ · 3BR, 3BR+',
      ),
      (key: 'handover', label: 'Bàn giao', value: '2028'),
      (key: 'phap_ly', label: 'Pháp lý', value: 'Sở hữu lâu dài'),
      (key: 'quy_mo', label: 'Quy mô', value: '4 tòa tháp ·'),
      (key: 'so_can', label: 'Số căn', value: '1785'),
    ]);
    expect(o.source, 'https://smartrealtors.vn/beachtro-tower-blanca-city/');
  });
  test('USP caps ten and non-http source ignored', () {
    final o = parseOverview({
      'usp': List.generate(12, (i) => 'Điểm $i'),
      'source_url': 'javascript:x',
    });
    expect(o.usp, hasLength(10));
    expect(o.source, isNull);
    expect(o.summary, isNull);
  });
  test('null empty and malformed values do not break rendering', () {
    final empty = parseOverview(null);
    expect(empty.summary, isNull);
    expect(empty.usp, isEmpty);
    expect(empty.specs, isEmpty);
    expect(empty.source, isNull);
    expect(parseOverview({'description': '   '}).summary, isNull);
    expect(parseOverview({'scale': true, 'units': <Object?>[]}).specs, isEmpty);
  });
  test('amenities support strings objects and newline-separated values', () {
    expect(
      amenitiesOf({
        'tien_ich': [
          'Hồ bơi',
          {'name': 'Gym'},
          '',
        ],
      }),
      ['Hồ bơi', 'Gym'],
    );
    expect(amenitiesOf({'amenities': 'Công viên\n Trường học \n'}), [
      'Công viên',
      'Trường học',
    ]);
    expect(amenitiesOf(null), isEmpty);
  });
  test('floor plans accept URL aliases and default missing names to Xem', () {
    expect(
      floorPlansOf({
        'mat_bang': [
          {'name': 'Tầng 1', 'url': 'https://x/1.jpg'},
          {'image': 'https://x/2.jpg'},
        ],
      }),
      [
        (name: 'Tầng 1', url: 'https://x/1.jpg'),
        (name: 'Xem', url: 'https://x/2.jpg'),
      ],
    );
  });
  test('known labels translated, unknown keys capitalized and spaced', () {
    expect(specLabel('phap_ly'), 'Pháp lý');
    expect(specLabel('mat_do_cay_xanh'), 'Mat do cay xanh');
    expect(specLabel('Loại hình'), 'Loại hình');
  });
}
