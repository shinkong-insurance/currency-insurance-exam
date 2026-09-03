import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/content_cache_store.dart';
import '../models/chapter.dart';
import '../models/question.dart';
import '../models/section.dart';

abstract class ContentSource {
  Future<List<Map<String, dynamic>>> fetchQuestions();
  Future<List<Map<String, dynamic>>> fetchChapters();
  Future<List<Map<String, dynamic>>> fetchSections();
}

class SupabaseContentSource implements ContentSource {
  final _sb = Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchQuestions() async =>
      List<Map<String, dynamic>>.from(await _sb.from('questions').select());

  @override
  Future<List<Map<String, dynamic>>> fetchChapters() async =>
      List<Map<String, dynamic>>.from(await _sb.from('chapters').select());

  @override
  Future<List<Map<String, dynamic>>> fetchSections() async =>
      List<Map<String, dynamic>>.from(await _sb.from('sections').select());
}

class QuestionRepository {
  final ContentSource source;
  final ContentCacheStore cache;
  List<Chapter>? _chapters;
  List<Question>? _questions;
  List<Section>? _sections;

  QuestionRepository({ContentSource? source, ContentCacheStore? cache})
      : source = source ?? SupabaseContentSource(),
        cache = cache ?? ContentCacheStore(SharedPreferences.getInstance());

  Future<List<Question>> getAllQuestions() async {
    if (_questions != null) return _questions!;
    var rows = await cache.read('questions');
    rows ??= await source.fetchQuestions();
    unawaited(_refreshQuestionsInBackground());
    _questions = rows.map((r) => Question.fromSupabaseRow(r)).toList();
    return _questions!;
  }

  Future<void> _refreshQuestionsInBackground() async {
    try {
      final fresh = await source.fetchQuestions();
      await cache.write('questions', fresh);
      _questions = fresh.map((r) => Question.fromSupabaseRow(r)).toList();
    } catch (_) {
      // 背景刷新失敗不影響已顯示的內容
    }
  }

  Future<List<Chapter>> getChapters() async {
    if (_chapters != null) return _chapters!;
    var rows = await cache.read('chapters');
    rows ??= await source.fetchChapters();
    unawaited(_refreshChaptersInBackground());
    _chapters = rows.map((r) => Chapter.fromSupabaseRow(r)).toList();
    return _chapters!;
  }

  Future<void> _refreshChaptersInBackground() async {
    try {
      final fresh = await source.fetchChapters();
      await cache.write('chapters', fresh);
      _chapters = fresh.map((r) => Chapter.fromSupabaseRow(r)).toList();
    } catch (_) {
      // 背景刷新失敗不影響已顯示的內容
    }
  }

  Future<List<Section>> getAllSections() async {
    if (_sections != null) return _sections!;
    var rows = await cache.read('sections');
    rows ??= await source.fetchSections();
    unawaited(_refreshSectionsInBackground());
    _sections = rows.map((r) => Section.fromSupabaseRow(r)).toList();
    return _sections!;
  }

  Future<void> _refreshSectionsInBackground() async {
    try {
      final fresh = await source.fetchSections();
      await cache.write('sections', fresh);
      _sections = fresh.map((r) => Section.fromSupabaseRow(r)).toList();
    } catch (_) {
      // 背景刷新失敗不影響已顯示的內容
    }
  }

  Future<List<Section>> getSectionsByChapter(int chapterId) async {
    final all = await getAllSections();
    final result = all.where((s) => s.chapterId == chapterId).toList();
    result.sort((a, b) => a.order.compareTo(b.order));
    return result;
  }

  Future<List<Question>> getQuestionsByChapter(int chapterId) async {
    final all = await getAllQuestions();
    return all.where((q) => q.chapterId == chapterId).toList();
  }

  Future<List<Question>> getQuestionsByIds(List<int> ids) async {
    final all = await getAllQuestions();
    final idSet = ids.toSet();
    return all.where((q) => idSet.contains(q.id)).toList();
  }

  Future<List<Question>> getRandomQuestions(int count, {int? chapterId}) async {
    final all = await getAllQuestions();
    final pool = chapterId != null
        ? all.where((q) => q.chapterId == chapterId).toList()
        : all;
    pool.shuffle();
    return pool.take(count).toList();
  }

  /// 錯題優先組題：先將錯題全數納入，再以隨機題目補足 count 題。
  /// 結果打亂順序，確保考生無法從位置判斷哪些是錯題。
  /// wrongIds：當前錯題本中所有題目的 id
  ///
  /// 註：本 APP 沒有「保險實務 / 保險法規」兩科之分（那是壽險姊妹 APP 的結構），
  /// 所以不再依 courseId 篩選；題目一律取自完整題庫。
  Future<List<Question>> getExamQuestionsWithWrongPriority(
    int count,
    List<int> wrongIds,
  ) async {
    final all = await getAllQuestions();

    final wrongSet = wrongIds.toSet();
    final wrongQs = all.where((q) => wrongSet.contains(q.id)).toList();
    // 非錯題（隨機補位用）
    final randomPool = all.where((q) => !wrongSet.contains(q.id)).toList()
      ..shuffle();

    final result = <Question>[];
    result.addAll(wrongQs.take(count));          // 錯題優先，最多 count 題
    final remaining = count - result.length;
    if (remaining > 0) result.addAll(randomPool.take(remaining)); // 補齊
    result.shuffle();                            // 打亂，隱藏錯題位置
    return result;
  }
}
