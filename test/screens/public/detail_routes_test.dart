import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/screens/public/detail_routes.dart';

void main() {
  for (final path in [
    '/cong-khai/:code',
    '/bai-viet/:slug',
    '/chu-dau-tu/:slug',
    '/tinh-lai-vay',
    '/chinh-sach-bao-mat',
    '/xem',
    '/tour-360',
  ]) {
    test('$path has a public detail screen instead of a placeholder', () {
      expect(publicDetailScreens[path], isNotNull);
    });
  }
}
