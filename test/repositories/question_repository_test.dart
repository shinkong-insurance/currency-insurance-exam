import 'package:flutter_test/flutter_test.dart';
import 'package:currency_insurance_exam/repositories/question_repository.dart';
import 'package:currency_insurance_exam/core/services/content_cache_store.dart';
import 'fakes/fake_supabase_content_source.dart';

void main() {
  test('getAllQuestions parses rows from Supabase into Question models', () async {
    final fakeSource = FakeSupabaseContentSource(questionRows: [
      {
        'id': 1, 'chapter_id': 101, 'question_no': 1, 'question': '測試題目',
        'options': ['A', 'B', 'C', 'D'], 'answer': 2, 'explanation': '解析',
        'keyword_hint': '關鍵詞', 'plain_explanation': '簡單說明', 'textbook_page': 5,
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    final questions = await repo.getAllQuestions();

    expect(questions.length, 1);
    expect(questions.first.id, 1);
    expect(questions.first.answer, 2);
    expect(questions.first.options, ['A', 'B', 'C', 'D']);
    expect(questions.first.textbookPage, 5);
    expect(questions.first.keywordHint, '關鍵詞');
    expect(questions.first.plainExplanation, '簡單說明');
  });

  test('getChapters parses chapter rows correctly', () async {
    final fakeSource = FakeSupabaseContentSource(chapterRows: [
      {
        'id': 101, 'course_id': 1, 'unit_no': 1, 'title': '第一章',
        'weight': '15%',
      },
      {
        'id': 102, 'course_id': 1, 'unit_no': 2, 'title': '第二章',
        'weight': '20%',
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    final chapters = await repo.getChapters();

    expect(chapters.length, 2);
    expect(chapters[0].id, 101);
    expect(chapters[0].courseId, 1);
    expect(chapters[0].unitNo, 1);
    expect(chapters[0].title, '第一章');
    expect(chapters[0].weight, '15%');
    expect(chapters[1].id, 102);
    expect(chapters[1].unitNo, 2);
  });

  test('getAllSections parses section rows correctly', () async {
    final fakeSource = FakeSupabaseContentSource(sectionRows: [
      {
        'id': 1001, 'chapter_id': 101, 'order': 1, 'title': '第一節',
        'content': '內容一',
      },
      {
        'id': 1002, 'chapter_id': 101, 'order': 2, 'title': '第二節',
        'content': '內容二',
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    final sections = await repo.getAllSections();

    expect(sections.length, 2);
    expect(sections[0].id, 1001);
    expect(sections[0].chapterId, 101);
    expect(sections[0].order, 1);
    expect(sections[0].title, '第一節');
  });

  test('getSectionsByChapter filters sections and sorts by order', () async {
    final fakeSource = FakeSupabaseContentSource(sectionRows: [
      {
        'id': 1001, 'chapter_id': 101, 'order': 2, 'title': '第二節',
        'content': '內容二',
      },
      {
        'id': 1002, 'chapter_id': 102, 'order': 1, 'title': '其他章第一節',
        'content': '內容',
      },
      {
        'id': 1003, 'chapter_id': 101, 'order': 1, 'title': '第一節',
        'content': '內容一',
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    final sections = await repo.getSectionsByChapter(101);

    expect(sections.length, 2);
    // Verify sorted by order
    expect(sections[0].order, 1);
    expect(sections[0].title, '第一節');
    expect(sections[1].order, 2);
    expect(sections[1].title, '第二節');
    // Verify only chapter 101
    expect(sections.every((s) => s.chapterId == 101), true);
  });

  test('getQuestionsByChapter returns only matching chapter questions', () async {
    final fakeSource = FakeSupabaseContentSource(questionRows: [
      {
        'id': 1, 'chapter_id': 101, 'question_no': 1, 'question': '題目1',
        'options': ['A', 'B'], 'answer': 1, 'explanation': '解析1',
        'keyword_hint': null, 'plain_explanation': null, 'textbook_page': null,
      },
      {
        'id': 2, 'chapter_id': 102, 'question_no': 1, 'question': '題目2',
        'options': ['A', 'B'], 'answer': 1, 'explanation': '解析2',
        'keyword_hint': null, 'plain_explanation': null, 'textbook_page': null,
      },
      {
        'id': 3, 'chapter_id': 101, 'question_no': 2, 'question': '題目3',
        'options': ['A', 'B'], 'answer': 2, 'explanation': '解析3',
        'keyword_hint': null, 'plain_explanation': null, 'textbook_page': null,
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    final questions = await repo.getQuestionsByChapter(101);

    expect(questions.length, 2);
    expect(questions[0].id, 1);
    expect(questions[1].id, 3);
    expect(questions.every((q) => q.chapterId == 101), true);
  });

  test('getQuestionsByIds returns exactly requested questions', () async {
    final fakeSource = FakeSupabaseContentSource(questionRows: [
      {
        'id': 1, 'chapter_id': 101, 'question_no': 1, 'question': '題目1',
        'options': ['A', 'B'], 'answer': 1, 'explanation': '解析1',
        'keyword_hint': null, 'plain_explanation': null, 'textbook_page': null,
      },
      {
        'id': 2, 'chapter_id': 102, 'question_no': 1, 'question': '題目2',
        'options': ['A', 'B'], 'answer': 1, 'explanation': '解析2',
        'keyword_hint': null, 'plain_explanation': null, 'textbook_page': null,
      },
      {
        'id': 3, 'chapter_id': 101, 'question_no': 2, 'question': '題目3',
        'options': ['A', 'B'], 'answer': 2, 'explanation': '解析3',
        'keyword_hint': null, 'plain_explanation': null, 'textbook_page': null,
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    final questions = await repo.getQuestionsByIds([2, 3]);

    expect(questions.length, 2);
    expect(questions.map((q) => q.id).toSet(), {2, 3});
  });

  test('cache-hit: second call to getAllQuestions does not re-invoke source fetch',
      () async {
    final fakeSource = FakeSupabaseContentSource(questionRows: [
      {
        'id': 1, 'chapter_id': 101, 'question_no': 1, 'question': '題目1',
        'options': ['A', 'B'], 'answer': 1, 'explanation': '解析1',
        'keyword_hint': null, 'plain_explanation': null, 'textbook_page': null,
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    // First call
    await repo.getAllQuestions();
    final callCountAfterFirst = fakeSource.fetchQuestionsCallCount;

    // Wait for background refresh to complete
    await Future.delayed(Duration(milliseconds: 100));

    // Second call should use in-memory cache and not trigger additional fetches
    await repo.getAllQuestions();
    expect(fakeSource.fetchQuestionsCallCount, callCountAfterFirst);
  });

  test('cache-hit: second call to getChapters does not re-invoke source fetch',
      () async {
    final fakeSource = FakeSupabaseContentSource(chapterRows: [
      {
        'id': 101, 'course_id': 1, 'unit_no': 1, 'title': '第一章',
        'weight': '15%',
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    // First call
    await repo.getChapters();
    final callCountAfterFirst = fakeSource.fetchChaptersCallCount;

    // Wait for background refresh to complete
    await Future.delayed(Duration(milliseconds: 100));

    // Second call should use in-memory cache and not trigger additional fetches
    await repo.getChapters();
    expect(fakeSource.fetchChaptersCallCount, callCountAfterFirst);
  });

  test('cache-hit: second call to getAllSections does not re-invoke source fetch',
      () async {
    final fakeSource = FakeSupabaseContentSource(sectionRows: [
      {
        'id': 1001, 'chapter_id': 101, 'order': 1, 'title': '第一節',
        'content': '內容一',
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    // First call
    await repo.getAllSections();
    final callCountAfterFirst = fakeSource.fetchSectionsCallCount;

    // Wait for background refresh to complete
    await Future.delayed(Duration(milliseconds: 100));

    // Second call should use in-memory cache and not trigger additional fetches
    await repo.getAllSections();
    expect(fakeSource.fetchSectionsCallCount, callCountAfterFirst);
  });
}
