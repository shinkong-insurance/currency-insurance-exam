import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:currency_insurance_exam/features/quiz/quiz_page.dart';
import 'package:currency_insurance_exam/providers/user_data_provider.dart';
import 'package:currency_insurance_exam/providers/question_provider.dart';
import 'package:currency_insurance_exam/repositories/user_data_repository.dart';
import 'package:currency_insurance_exam/repositories/question_repository.dart';
import 'package:currency_insurance_exam/core/database/shared_preferences_store.dart';
import 'package:currency_insurance_exam/core/services/content_cache_store.dart';
import '../../repositories/fakes/fake_supabase_content_source.dart';

// 注意：`UserDataRepository.addWrong()` 一律把 next_review_date 排到「明天」
// （見 lib/models/wrong_book.dart 的 isDue 註解與
// test/repositories/user_data_repository_wrongbook_test.dart 的
// 「excludes a question freshly scheduled for tomorrow」測試），所以單純呼叫
// addWrong 不會讓題目「今天就到期」。這裡改用直接寫入 wrong_book 的方式，種一筆
// next_review_date 是「昨天」的錯題記錄，讓題目確實進入「今日待複習」。
//
// 另外 `SharedPreferencesStore` 是 process 級單例（`_instance ??=` +
// `_prefs ??=`），它快取的 SharedPreferences 物件在第一次建立後，不會因為之後
// 再呼叫 `SharedPreferences.setMockInitialValues()` 而更新內容（那只是替換底層
// mock 平台，對已經快取好的 SharedPreferences 實例沒有影響）。所以每個測試改成
// 透過同一顆已快取的 SharedPreferences 實例直接 clear + 寫入，確保測試之間不會
// 因為單例快取而互相污染狀態。
Future<void> _seedWrongBook(Map<String, dynamic> entries) async {
  final prefs = await SharedPreferencesStore.instance.prefs;
  await prefs.clear();
  await prefs.setString('fx_wrong_book', json.encode(entries));
}

Map<String, dynamic> _dueEntry(int questionId, {int correctStreak = 0}) {
  final yesterday = DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);
  return {
    'question_id': questionId,
    'wrong_count': 1,
    'correct_streak': correctStreak,
    'last_wrong_time': DateTime.now().toIso8601String(),
    'next_review_date': yesterday,
  };
}

QuestionRepository _fakeQuestionRepo() => QuestionRepository(
      source: FakeSupabaseContentSource(questionRows: [
        {
          'id': 1,
          'chapter_id': 101,
          'question_no': 1,
          'question': '測試題目1',
          'options': ['A', 'B', 'C', 'D'],
          'answer': 2, // 正確答案是選項 B（index 1）
          'explanation': '解析',
        },
      ]),
      cache: ContentCacheStore.inMemory(),
    );

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'review mode shows 今日複習 title, loads due wrong-book question, and does not touch chapter progress',
      (tester) async {
    await _seedWrongBook({'1': _dueEntry(1)});
    final repo = UserDataRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDataRepositoryProvider.overrideWithValue(repo),
        questionRepositoryProvider.overrideWithValue(_fakeQuestionRepo()),
      ],
      child:
          const MaterialApp(home: QuizPage(chapterId: 0, isReviewMode: true)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('今日複習'), findsOneWidget);
    expect(find.text('測試題目1'), findsOneWidget);

    final progress = await repo.getProgress();
    expect(
        progress.containsKey(0), isFalse); // chapterId 0 是複習模式的佔位值，不應寫入任何章節進度
  });

  testWidgets(
      'a correct answer in review mode calls markReviewedCorrect, not addWrong',
      (tester) async {
    await _seedWrongBook({'1': _dueEntry(1)});
    final repo = UserDataRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDataRepositoryProvider.overrideWithValue(repo),
        questionRepositoryProvider.overrideWithValue(_fakeQuestionRepo()),
      ],
      child:
          const MaterialApp(home: QuizPage(chapterId: 0, isReviewMode: true)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('B')); // 正確答案
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    final books = await repo.getWrongBooks();
    // markReviewedCorrect: streak 0 -> 1（未達 2 次不會被移出錯題本），
    // 若誤呼叫 addWrong 則 streak 會被歸零成 0，藉此區分兩者。
    expect(books.length, 1);
    expect(books.first.correctStreak, 1);

    final progress = await repo.getProgress();
    expect(progress.containsKey(0), isFalse);
  });

  testWidgets(
      'a wrong answer in review mode calls markReviewedWrong and resets the streak',
      (tester) async {
    await _seedWrongBook({'1': _dueEntry(1, correctStreak: 1)});
    final repo = UserDataRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDataRepositoryProvider.overrideWithValue(repo),
        questionRepositoryProvider.overrideWithValue(_fakeQuestionRepo()),
      ],
      child:
          const MaterialApp(home: QuizPage(chapterId: 0, isReviewMode: true)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A')); // 錯誤答案
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    final books = await repo.getWrongBooks();
    expect(books.length, 1);
    expect(books.first.correctStreak, 0); // markReviewedWrong 歸零 streak、排到明天

    final progress = await repo.getProgress();
    expect(progress.containsKey(0), isFalse);
  });
}
