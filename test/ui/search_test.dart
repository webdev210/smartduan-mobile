import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/search.dart';

void main() {
  test('fold removes accents, đ, case and extra whitespace', () {
    expect(fold('Bình  Dương'), 'binh duong');
    expect(fold('ĐỒNG NAI'), 'dong nai');
    expect(fold('  Thủ Đức '), 'thu duc');
    expect(fold(null), '');
  });
  final items = [
    ('The Sunrise', 'Bình Dương'),
    ('Blue Tower', 'Sun Group'),
    ('Sun Urban City', 'Hà Nam'),
    ('Vinhomes Grand Park', 'TP.HCM'),
  ];
  List<String> find(String q) =>
      smartFilter(items, q, (x) => [x.$1, x.$2]).map((x) => x.$1).toList();
  test('empty query preserves the original list', () {
    expect(identical(smartFilter(items, '  ', (x) => [x.$1]), items), true);
  });
  test('all words match across fields in any order without accents', () {
    expect(find('grand vin'), ['Vinhomes Grand Park']);
    expect(find('binh duong'), ['The Sunrise']);
    expect(find('hcm park'), ['Vinhomes Grand Park']);
  });
  test('every word must match', () => expect(find('sun xyz'), isEmpty));
  test('title prefix then word prefix then other fields', () {
    expect(find('sun'), ['Sun Urban City', 'The Sunrise', 'Blue Tower']);
    expect(titleScore('Unsung', 'sun'), 1);
  });
}
