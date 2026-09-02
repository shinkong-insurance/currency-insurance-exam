import 'package:currency_insurance_exam/repositories/question_repository.dart';

class FakeSupabaseContentSource implements ContentSource {
  final List<Map<String, dynamic>> questionRows;
  final List<Map<String, dynamic>> chapterRows;
  final List<Map<String, dynamic>> sectionRows;

  FakeSupabaseContentSource({
    this.questionRows = const [],
    this.chapterRows = const [],
    this.sectionRows = const [],
  });

  @override
  Future<List<Map<String, dynamic>>> fetchQuestions() async => questionRows;

  @override
  Future<List<Map<String, dynamic>>> fetchChapters() async => chapterRows;

  @override
  Future<List<Map<String, dynamic>>> fetchSections() async => sectionRows;
}
