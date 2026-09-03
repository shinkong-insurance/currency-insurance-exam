// 回歸測試：同一題重複作答必須是無效操作（I2）。
//
// 舊版 QuizPage 只用一個 `_showAnswer` bool 記錄「是否已顯示答案」，而
// `_prevQuestion()` 會把它重設成 false。於是「答題 → 下一題 → 上一題 →
// 再答同一題」會讓所有副作用重跑一遍：
//   * 複習模式重複呼叫 markReviewedCorrect，streak 連跳兩格，錯題提前畢業；
//   * 關卡模式 _correctCount 會超過題數，存進 level_progress 的 correct 大於
//     attempted；
//   * 一般模式則會重複 addWrong，灌水 wrong_count。
//
// 現在改成用 `_answeredSelections`（題目索引 -> 選擇的答案）查表，重複作答
// 直接 return。

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:currency_insurance_exam/features/quiz/quiz_page.dart';
import 'package:currency_insurance_exam/models/level.dart';
import 'package:currency_insurance_exam/providers/level_provider.dart';
import 'package:currency_insurance_exam/providers/question_provider.dart';
import 'package:currency_insurance_exam/providers/user_data_provider.dart';
import 'package:currency_insurance_exam/repositories/level_repository.dart';
import 'package:currency_insurance_exam/repositories/question_repository.dart';
import 'package:currency_insurance_exam/repositories/user_data_repository.dart';
import 'package:currency_insurance_exam/core/database/shared_preferences_store.dart';
import 'package:currency_insurance_exam/core/services/content_cache_store.dart';
import '../../repositories/fakes/fake_supabase_content_source.dart';

class FakeLevelRepository extends LevelRepository {
  final List<Map<String, dynamic>> savedCalls = [];

  @override
  Future<List<Level>> getLevels() async => [];

  @override
  Future<bool> isLevelPassed(int levelId) async => false;

  @override
  Future<void> saveLevelProgress(int levelId,
      {required int attempted,
      required int correct,
      required bool passed}) async {
    savedCalls.add({
      'levelId': levelId,
      'attempted': attempted,
      'correct': correct,
      'passed': passed,
    });
  }
}

// 兩題都以「B」為正解，方便在測試裡重複點同一個選項。
QuestionRepository _fakeQuestionRepo() => QuestionRepository(
      source: FakeSupabaseContentSource(questionRows: [
        {
          'id': 1,
          'chapter_id': 1,
          'question_no': 1,
          'question': '題目1',
          'options': ['A', 'B', 'C', 'D'],
          'answer': 2,
          'explanation': '解析1',
        },
        {
          'id': 2,
          'chapter_id': 1,
          'question_no': 2,
          'question': '題目2',
          'options': ['A', 'B', 'C', 'D'],
          'answer': 2,
          'explanation': '解析2',
        },
      ]),
      cache: ContentCacheStore.inMemory(),
    );

Future<void> _seedWrongBook(Map<String, dynamic> entries) async {
  final prefs = await SharedPreferencesStore.instance.prefs;
  await prefs.clear();
  await prefs.setString('wrong_book', json.encode(entries));
}

Map<String, dynamic> _dueEntry(int questionId) {
  final yesterday = DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);
  return {
    'question_id': questionId,
    'wrong_count': 1,
    'correct_streak': 0,
    'last_wrong_time': DateTime.now().toIso8601String(),
    'next_review_date': yesterday,
  };
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  final level = Level(
      id: 1,
      order: 1,
      label: '第1關',
      chapterId: 1,
      questionIds: const [1, 2],
      passThreshold: 0.7);

  testWidgets(
      'level mode: re-answering an already-answered question does not double-count it',
      (tester) async {
    final prefs = await SharedPreferencesStore.instance.prefs;
    await prefs.clear();

    final fakeLevelRepo = FakeLevelRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        levelByIdProvider(1).overrideWith((ref) async => level),
        levelRepositoryProvider.overrideWithValue(fakeLevelRepo),
        questionRepositoryProvider.overrideWithValue(_fakeQuestionRepo()),
        userDataRepositoryProvider.overrideWithValue(UserDataRepository()),
      ],
      child: const MaterialApp(home: QuizPage(chapterId: 0, levelId: 1)),
    ));
    await tester.pumpAndSettle();

    // 第 1 題答對
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一題'));
    await tester.pumpAndSettle();

    // 第 2 題答對
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    // 回到第 1 題，再答一次同一題
    await tester.tap(find.text('上一題'));
    await tester.pumpAndSettle();
    // 已作答的題目應該仍在顯示上次的結果
    expect(find.text('題目1'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    // 回到第 2 題完成整關
    await tester.tap(find.text('下一題'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // 關鍵：correct 必須是 2（每題各算一次），不是 3。
    expect(fakeLevelRepo.savedCalls.length, 1);
    expect(fakeLevelRepo.savedCalls.first['attempted'], 2);
    expect(fakeLevelRepo.savedCalls.first['correct'], 2);
  });

  testWidgets(
      'review mode: re-answering an already-answered question fires markReviewedCorrect only once',
      (tester) async {
    await _seedWrongBook({'1': _dueEntry(1), '2': _dueEntry(2)});
    final userRepo = UserDataRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDataRepositoryProvider.overrideWithValue(userRepo),
        questionRepositoryProvider.overrideWithValue(_fakeQuestionRepo()),
      ],
      child:
          const MaterialApp(home: QuizPage(chapterId: 0, isReviewMode: true)),
    ));
    await tester.pumpAndSettle();

    // 第 1 題答對 -> markReviewedCorrect 一次，streak 0 -> 1
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一題'));
    await tester.pumpAndSettle();

    // 回到第 1 題再答一次
    await tester.tap(find.text('上一題'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    // 關鍵：若 markReviewedCorrect 跑了第二次，streak 會變成 2，該題就會被
    // 移出錯題本（見 UserDataRepository.markReviewedCorrect 的畢業條件），
    // 錯題本只剩第 2 題。正確行為是只跑一次，streak 停在 1、題目還在。
    final books = await userRepo.getWrongBooks();
    final q1 = books.where((b) => b.questionId == 1).toList();
    expect(q1.length, 1, reason: '第 1 題不應因為重複作答而提前畢業出錯題本');
    expect(q1.first.correctStreak, 1);
  });
}
