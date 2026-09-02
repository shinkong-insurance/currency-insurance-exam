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
        'keyword_hint': null, 'plain_explanation': null, 'textbook_page': 5,
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
  });
}
