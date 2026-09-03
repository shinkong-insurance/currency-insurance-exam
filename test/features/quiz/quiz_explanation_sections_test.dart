import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:currency_insurance_exam/features/quiz/widgets/explanation_panel.dart';
import 'package:currency_insurance_exam/models/question.dart';

void main() {
  testWidgets('shows keyword hint and plain explanation when both present', (tester) async {
    final q = Question(id: 1, chapterId: 1, questionNo: 1, question: 'q',
        options: const ['a','b','c','d'], answer: 1, explanation: '法規解析',
        keywordHint: '結匯→向銀行業辦理', plainExplanation: '白話說明文字', textbookPage: 23);
    await tester.pumpWidget(MaterialApp(home: ExplanationPanel(question: q)));
    expect(find.textContaining('🎯 關鍵字破題'), findsOneWidget);
    expect(find.textContaining('結匯→向銀行業辦理'), findsOneWidget);
    expect(find.textContaining('💬 白話告訴你為什麼'), findsOneWidget);
  });

  testWidgets('hides plain explanation section when not yet generated', (tester) async {
    final q = Question(id: 1, chapterId: 1, questionNo: 1, question: 'q',
        options: const ['a','b','c','d'], answer: 1, explanation: '法規解析',
        keywordHint: '提示', plainExplanation: null, textbookPage: 23);
    await tester.pumpWidget(MaterialApp(home: ExplanationPanel(question: q)));
    expect(find.textContaining('🎯 關鍵字破題'), findsOneWidget);
    expect(find.textContaining('💬 白話告訴你為什麼'), findsNothing);
  });

  // 114 題中有 21 題的 explanation 是空字串，這時不應該印出一個下面空無一物的
  // 「📖 法規解析:」標題。
  testWidgets('hides the 法規解析 section when explanation is empty',
      (tester) async {
    final q = Question(id: 1, chapterId: 1, questionNo: 1, question: 'q',
        options: const ['a','b','c','d'], answer: 1, explanation: '',
        keywordHint: '提示', plainExplanation: null, textbookPage: 23);
    await tester.pumpWidget(MaterialApp(home: ExplanationPanel(question: q)));
    expect(find.textContaining('🎯 關鍵字破題'), findsOneWidget);
    expect(find.textContaining('📖 法規解析'), findsNothing);
  });

  testWidgets('shows the 法規解析 section when explanation is present',
      (tester) async {
    final q = Question(id: 1, chapterId: 1, questionNo: 1, question: 'q',
        options: const ['a','b','c','d'], answer: 1, explanation: '法規解析內容',
        keywordHint: null, plainExplanation: null, textbookPage: null);
    await tester.pumpWidget(MaterialApp(home: ExplanationPanel(question: q)));
    expect(find.textContaining('📖 法規解析'), findsOneWidget);
    expect(find.textContaining('法規解析內容'), findsOneWidget);
  });
}
