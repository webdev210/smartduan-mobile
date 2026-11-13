import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/project_compare.dart';

void main() {
  late ProviderContainer container;
  late ProjectCompare basket;
  setUp(() {
    container = ProviderContainer();
    basket = container.read(projectCompareProvider.notifier);
  });
  tearDown(() => container.dispose());
  test('first tap adds, second tap removes', () {
    expect(basket.toggle('A'), true);
    expect(container.read(projectCompareProvider), ['A']);
    basket.toggle('A');
    expect(container.read(projectCompareProvider), isEmpty);
  });
  test('three codes reject a fourth without changing the basket', () {
    for (final code in ['A', 'B', 'C']) {
      basket.toggle(code);
    }
    expect(basket.toggle('D'), false);
    expect(container.read(projectCompareProvider), ['A', 'B', 'C']);
  });
  test('holding add keeps an existing code', () {
    basket.add('A');
    expect(basket.add('A'), true);
    expect(container.read(projectCompareProvider), ['A']);
  });
  test('listeners are notified until unsubscribed', () {
    var calls = 0;
    final subscription = container.listen(
      projectCompareProvider,
      (_, _) => calls++,
    );
    basket.toggle('A');
    basket.remove('A');
    subscription.close();
    basket.toggle('B');
    expect(calls, 2);
  });
}
