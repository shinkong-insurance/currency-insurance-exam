import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:currency_insurance_exam/features/quiz/quiz_page.dart';
import 'package:currency_insurance_exam/providers/level_provider.dart';
import 'package:currency_insurance_exam/providers/user_data_provider.dart';
import 'package:currency_insurance_exam/providers/question_provider.dart';
import 'package:currency_insurance_exam/repositories/level_repository.dart';
import 'package:currency_insurance_exam/repositories/user_data_repository.dart';
import 'package:currency_insurance_exam/repositories/question_repository.dart';
import 'package:currency_insurance_exam/core/database/shared_preferences_store.dart';
import 'package:currency_insurance_exam/core/services/content_cache_store.dart';
import 'package:currency_insurance_exam/models/level.dart';
import 'package:flutter/material.dart';
import '../../repositories/fakes/fake_supabase_content_source.dart';

// LevelRepository 內部欄位改為 lazy getter 存取 Supabase.instance.client（見
// lib/repositories/level_repository.dart），所以子類別只要不呼叫繼承來的實作，
// 就可以在完全不初始化 Supabase 的測試環境下安全建構、記錄呼叫參數。
class FakeLevelRepository extends LevelRepository {
  final List<Map<String, dynamic>> savedCalls = [];

  @override
  Future<List<Level>> getLevels() async => [];

  @override
  Future<bool> isLevelPassed(int levelId) async => false;

  @override
  Future<void> saveLevelProgress(int levelId,
      {required int attempted, required int correct, required bool passed}) async {
    savedCalls.add({
      'levelId': levelId,
      'attempted': attempted,
      'correct': correct,
      'passed': passed,
    });
  }
}

QuestionRepository _fakeQuestionRepo() => QuestionRepository(
      source: FakeSupabaseContentSource(questionRows: [
        {
          'id': 1,
          'chapter_id': 1,
          'question_no': 1,
          'question': '關卡題目1',
          'options': ['A', 'B', 'C', 'D'],
          'answer': 2,
          'explanation': '解析1',
        },
        {
          'id': 2,
          'chapter_id': 1,
          'question_no': 2,
          'question': '關卡題目2',
          'options': ['A', 'B', 'C', 'D'],
          'answer': 1,
          'explanation': '解析2',
        },
      ]),
      cache: ContentCacheStore.inMemory(),
    );

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  final level = Level(
      id: 1, order: 1, label: '第1關', chapterId: 1,
      questionIds: const [1, 2], passThreshold: 0.7);

  testWidgets('level mode loads exactly the level\'s question ids', (tester) async {
    final prefs = await SharedPreferencesStore.instance.prefs;
    await prefs.clear();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        levelByIdProvider(1).overrideWith((ref) async => level),
        questionRepositoryProvider.overrideWithValue(_fakeQuestionRepo()),
        userDataRepositoryProvider.overrideWithValue(UserDataRepository()),
      ],
      child: const MaterialApp(home: QuizPage(chapterId: 0, levelId: 1)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('第 1 題 / 共 2 題'), findsOneWidget);
    expect(find.text('關卡題目1'), findsOneWidget);
  });

  testWidgets(
      'finishing a level writes ONLY level_progress (passed >= 70%), never the normal chapter progress',
      (tester) async {
    final prefs = await SharedPreferencesStore.instance.prefs;
    await prefs.clear();

    final fakeLevelRepo = FakeLevelRepository();
    final userRepo = UserDataRepository();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        levelByIdProvider(1).overrideWith((ref) async => level),
        levelRepositoryProvider.overrideWithValue(fakeLevelRepo),
        questionRepositoryProvider.overrideWithValue(_fakeQuestionRepo()),
        userDataRepositoryProvider.overrideWithValue(userRepo),
      ],
      child: const MaterialApp(home: QuizPage(chapterId: 0, levelId: 1)),
    ));
    await tester.pumpAndSettle();

    // 第 1 題：答對（answer=2 -> 選項 B）
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一題'));
    await tester.pumpAndSettle();

    // 第 2 題：答對（answer=1 -> 選項 A）
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(fakeLevelRepo.savedCalls.length, 1);
    expect(fakeLevelRepo.savedCalls.first, {
      'levelId': 1,
      'attempted': 2,
      'correct': 2,
      'passed': true, // 2/2 = 100% >= 70%
    });

    final progress = await userRepo.getProgress();
    expect(progress.containsKey(0), isFalse); // chapterId 0 是關卡模式佔位值，不應寫入章節進度
  });
}
