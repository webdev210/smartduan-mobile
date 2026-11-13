import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/ui/project_region_section.dart';

void main() {
  for (final (provinces, expected) in <(List<String?>, String)>[
    (['TP.HCM', 'Đà Nẵng', 'Hà Nội'], 'bac'),
    (['TP.HCM', 'Đà Nẵng'], 'trung'),
    (['TP.HCM'], 'nam'),
    ([], 'bac'),
    ([null, 'Không rõ'], 'bac'),
  ]) {
    test('first populated region for $provinces is $expected', () {
      expect(
        firstProjectRegion([
          for (final (i, province) in provinces.indexed)
            PublicProject(
              id: '$i',
              code: '$i',
              name: '$i',
              status: 'selling',
              province: province,
            ),
        ]),
        expected,
      );
    });
  }
}
