import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_insurance_exam/features/home/home_page.dart';
import 'package:currency_insurance_exam/providers/user_data_provider.dart';

void main() {
  testWidgets('shows due review count when greater than zero', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [dueReviewCountProvider.overrideWith((ref) async => 12)],
      child: const MaterialApp(home: HomePage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('今日待複習 12 題'), findsOneWidget);
  });

  testWidgets('hides the badge when due count is zero', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [dueReviewCountProvider.overrideWith((ref) async => 0)],
      child: const MaterialApp(home: HomePage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('今日待複習'), findsNothing);
  });
}
