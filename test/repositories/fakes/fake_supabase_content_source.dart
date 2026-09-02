import 'package:currency_insurance_exam/repositories/question_repository.dart';

class FakeSupabaseContentSource implements ContentSource {
  final List<Map<String, dynamic>> questionRows;
  final List<Map<String, dynamic>> chapterRows;
  final List<Map<String, dynamic>> sectionRows;

  int _fetchQuestionsCallCount = 0;
  int _fetchChaptersCallCount = 0;
  int _fetchSectionsCallCount = 0;

  FakeSupabaseContentSource({
    this.questionRows = const [],
    this.chapterRows = const [],
    this.sectionRows = const [],
  });

  int get fetchQuestionsCallCount => _fetchQuestionsCallCount;
  int get fetchChaptersCallCount => _fetchChaptersCallCount;
  int get fetchSectionsCallCount => _fetchSectionsCallCount;

  @override
  Future<List<Map<String, dynamic>>> fetchQuestions() async {
    _fetchQuestionsCallCount++;
    return questionRows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchChapters() async {
    _fetchChaptersCallCount++;
    return chapterRows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSections() async {
    _fetchSectionsCallCount++;
    return sectionRows;
  }
}
