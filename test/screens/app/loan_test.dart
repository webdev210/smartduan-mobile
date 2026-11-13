import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/sales.dart';
import 'package:smartduan/screens/app/loan.dart';
import 'package:smartduan/ui/loan_result_cards.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import 'task_h_fakes.dart';

void main() {
  for (final count in [12, 13, 107]) {
    testWidgets(
      'loan project search threshold and filtering for $count projects',
      (tester) async {
        final env = HEnv();
        env.http.respond = (_) => Reply(200, {
          'data': [
            for (var i = 0; i < count; i++)
              {
                'id': '$i',
                'code': 'P$i',
                'name': i == 0 ? 'Đông Sài Gòn' : 'Dự án $i',
              },
          ],
          'total': count,
        });
        await env.mount(tester, const LoanScreen());
        expect(
          find.byType(kit.SearchBar),
          count > 12 ? findsOneWidget : findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(kit.Chips).first,
            matching: find.byType(kit.Chip),
          ),
          findsNWidgets(count),
        );
        if (count <= 12) return;
        expect(
          tester.getBottomLeft(find.byType(kit.SearchBar)).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(kit.Chips).first).dy),
        );
        await tester.tap(find.text('Đông Sài Gòn'));
        final search = find.descendant(
          of: find.byType(kit.SearchBar),
          matching: find.byType(TextField),
        );
        await tester.enterText(search, 'du an 12');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(kit.Chips).first,
            matching: find.byType(kit.Chip),
          ),
          findsNWidgets(2),
        );
        expect(find.text('Đông Sài Gòn'), findsOneWidget);
        expect(find.text('Dự án 12'), findsOneWidget);
        await tester.enterText(search, 'dong sai gon');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(kit.Chips).first,
            matching: find.byType(kit.Chip),
          ),
          findsOneWidget,
        );
        await tester.enterText(search, 'no match');
        await tester.pumpAndSettle();
        expect(find.text('Đông Sài Gòn'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(kit.Chips).first,
            matching: find.byType(kit.Chip),
          ),
          findsOneWidget,
        );
        await tester.enterText(search, '');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(kit.Chips).first,
            matching: find.byType(kit.Chip),
          ),
          findsNWidgets(count),
        );
      },
    );
  }
  testWidgets('loan error and field error are visible, POST is not retried', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (_) => const Reply(422, {
      'error': 'validation',
      'message': 'Dữ liệu không hợp lệ',
      'details': {
        'floating_rate': ['Lãi suất không hợp lệ'],
      },
    });
    await env.mount(tester, const LoanScreen(unitId: 'u', code: 'A101'));
    await tester.tap(find.text('Tính'));
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu không hợp lệ'), findsOneWidget);
    expect(find.text('Lãi suất không hợp lệ'), findsOneWidget);
    expect(env.http.seen, hasLength(1));
    expect(env.http.seen.single.data, {
      'unit_id': 'u',
      'loan_ratio': 70,
      'term_months': 240,
    });
    expect(find.byType(LoanResultCards), findsNothing);
  });
  testWidgets(
    'project loan sends digits and manual overrides, renders policy label',
    (tester) async {
      final env = HEnv();
      env.http.respond = (r) => r.method == 'POST'
          ? const Reply(200, {
              'terms_source': 'policy',
              'fund': 'F2',
              'price': '400000000',
              'loan_amount': '280000000',
              'loan_ratio': 0.7,
              'schedule': <Object?>[],
            })
          : hReply(r.path);
      await env.mount(tester, const LoanScreen());
      await tester.tap(find.text('Dự án mẫu'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '400.000.000');
      await tester.ensureVisible(find.text('Điều chỉnh lãi suất / ưu đãi'));
      await tester.tap(find.text('Điều chỉnh lãi suất / ưu đãi'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(3), '8,5');
      await tester.enterText(find.byType(TextField).at(4), '12');
      await tester.ensureVisible(find.text('Tính'));
      await tester.tap(find.text('Tính'));
      await tester.pumpAndSettle();
      expect(env.http.seen.last.data, {
        'project_id': 'p',
        'price': '400000000',
        'loan_ratio': 70,
        'term_months': 240,
        'floating_rate': 8.5,
        'grace_months': 12,
      });
      expect(find.text('Theo CSBH quỹ F2'), findsOneWidget);
      expect(find.byType(LoanResultCards), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), '60');
      await tester.pump();
      expect(find.byType(LoanResultCards), findsNothing);
    },
  );
  testWidgets('invalid numeric input never sends POST', (tester) async {
    final env = HEnv();
    await env.mount(tester, const LoanScreen(unitId: 'u'));
    await tester.enterText(find.byType(TextField).at(0), 'NaN');
    await tester.tap(find.text('Tính'));
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu không hợp lệ'), findsOneWidget);
    expect(env.http.seen, isEmpty);
  });
  testWidgets('late loan result is discarded after sign-out', (tester) async {
    final env = HEnv();
    final pending = Completer<Reply>();
    env.http.respond = (_) => pending.future;
    await env.mount(tester, const LoanScreen(unitId: 'u'));
    await tester.tap(find.text('Tính'));
    await tester.pump();
    env.session.endSession();
    await tester.pump();
    pending.complete(const Reply(200, {'price': '400000000'}));
    await tester.pumpAndSettle();
    expect(find.byType(LoanResultCards), findsNothing);
  });
  test('loanTermsLabel keeps default and manual labels', () {
    expect(
      loanTermsLabel(LoanResult.fromJson({'terms_source': 'default'})),
      'Mặc định của sàn',
    );
    expect(
      loanTermsLabel(LoanResult.fromJson({'terms_source': 'manual'})),
      'Tự nhập — không theo CSBH',
    );
  });
}
