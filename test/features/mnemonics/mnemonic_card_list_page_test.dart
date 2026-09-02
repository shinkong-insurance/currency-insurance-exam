import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_insurance_exam/features/mnemonics/mnemonic_card_list_page.dart';
import 'package:currency_insurance_exam/models/mnemonic_card.dart';
import 'package:currency_insurance_exam/providers/mnemonic_provider.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('renders phrase and meaning for each card', (tester) async {
    final cards = [
      MnemonicCard(id: '1', chapterId: 2, phrase: '金三角',
          meaning: ['外匯存款存放同一銀行不得超過資金3%'], source: 'original'),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [mnemonicCardsProvider.overrideWith((ref) async => cards)],
      child: const MaterialApp(home: MnemonicCardListPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('金三角'), findsOneWidget);
    expect(find.textContaining('資金3%'), findsOneWidget);
  });

  testWidgets('shows empty state when no approved cards exist yet', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [mnemonicCardsProvider.overrideWith((ref) async => const [])],
      child: const MaterialApp(home: MnemonicCardListPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('尚未有口訣卡'), findsOneWidget);
  });
}
