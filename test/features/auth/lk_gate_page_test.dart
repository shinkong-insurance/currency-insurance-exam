import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:currency_insurance_exam/features/auth/lk_gate_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LkGatePage()));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to the 姓名/單位/員編 auto-register form', (tester) async {
    await pumpGate(tester);

    expect(find.text('姓名 *'), findsOneWidget);
    expect(find.text('單位 *'), findsOneWidget);
    expect(find.text('員編 *'), findsOneWidget);
    expect(find.text('送出並開始學習'), findsOneWidget);
    expect(find.text('授權碼'), findsNothing);
  });

  testWidgets('shows a validation error when required fields are empty', (tester) async {
    await pumpGate(tester);

    await tester.tap(find.text('送出並開始學習'));
    await tester.pumpAndSettle();

    expect(find.text('請填寫姓名'), findsOneWidget);
  });

  testWidgets('toggles to the key-login form and back', (tester) async {
    await pumpGate(tester);

    await tester.tap(find.text('改用授權碼登入'));
    await tester.pumpAndSettle();

    expect(find.text('授權碼'), findsOneWidget);
    expect(find.text('姓名 *'), findsNothing);

    await tester.tap(find.text('改用學員報名表單'));
    await tester.pumpAndSettle();

    expect(find.text('姓名 *'), findsOneWidget);
  });

  testWidgets('validates license key format before contacting Supabase', (tester) async {
    await pumpGate(tester);

    await tester.tap(find.text('改用授權碼登入'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'NOT-A-KEY');
    await tester.tap(find.text('驗證授權碼並進入'));
    await tester.pumpAndSettle();

    expect(find.textContaining('授權碼格式不正確'), findsOneWidget);
  });
}
