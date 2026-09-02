import 'dart:async';
import '../core/database/shared_preferences_store.dart';
import '../core/services/cloud_sync_service.dart';
import '../models/wrong_book.dart';
import '../models/exam_record.dart';

class UserDataRepository {
  final _store = SharedPreferencesStore.instance;

  // ── Wrong Book ──────────────────────────────────────────────

  Future<List<int>> getWrongQuestionIds() async {
    final data = await _store.getWrongBook();
    return data.keys.map(int.parse).toList();
  }

  Future<List<WrongBook>> getWrongBooks() async {
    final data = await _store.getWrongBook();
    return data.values
        .map((v) => WrongBook.fromMap(v as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.lastWrongTime.compareTo(a.lastWrongTime));
  }

  Future<void> addWrong(int questionId) async {
    await _store.addWrong(questionId);
    // LK 模式：同步到 Supabase（不等待，不影響 UI）
    unawaited(CloudSyncService.recordWrong(questionId.toString()));
  }

  Future<void> removeWrong(int questionId) async {
    await _store.removeWrong(questionId);
    unawaited(CloudSyncService.removeWrong(questionId.toString()));
  }

  /// 複習模式答對：streak+1，未達 2 則重排 +3 天；達 2 則移出錯題本。
  Future<void> markReviewedCorrect(int questionId) async {
    final books = await _store.getWrongBook();
    final entry = books[questionId.toString()];
    if (entry == null) return;
    final streak = (entry['correct_streak'] ?? 0) + 1;
    if (streak >= 2) {
      await removeWrong(questionId);
      return;
    }
    final nextReviewDate =
        DateTime.now().add(const Duration(days: 3)).toIso8601String().substring(0, 10);
    entry['correct_streak'] = streak;
    entry['next_review_date'] = nextReviewDate;
    await _store.updateWrongBookEntry(questionId, entry);
    unawaited(CloudSyncService.updateWrong(
      questionId.toString(),
      correctStreak: streak,
      nextReviewDate: nextReviewDate,
    ));
  }

  /// 複習模式答錯：等同重新記一次錯題（streak 歸零、排到明天）。
  Future<void> markReviewedWrong(int questionId) async {
    await addWrong(questionId); // addWrong 已經會把 correct_streak 歸零、排到明天
  }

  /// 一般練習模式作答：答錯照常記錯題；答對不動 wrong_book 的 streak/排程（spec §8.4）。
  Future<void> recordPracticeAnswer(int questionId, {required bool correct}) async {
    if (!correct) {
      await addWrong(questionId);
    }
  }

  Future<int> getDueReviewCount() async {
    final books = await getWrongBooks();
    return books.where((b) => b.isDue).length;
  }

  Future<List<int>> getDueWrongQuestionIds() async {
    final books = await getWrongBooks();
    return books.where((b) => b.isDue).map((b) => b.questionId).toList();
  }

  Future<void> clearWrongBook() async {
    await _store.clearWrongBook();
    unawaited(CloudSyncService.clearAllWrong());
  }

  // ── Favorite ────────────────────────────────────────────────

  Future<List<int>> getFavoriteIds() => _store.getFavoriteIds();
  Future<bool> isFavorite(int questionId) => _store.isFavorite(questionId);

  Future<void> toggleFavorite(int questionId) async {
    final wasFav = await _store.isFavorite(questionId);
    await _store.toggleFavorite(questionId);
    // LK 模式：同步到 Supabase
    if (wasFav) {
      unawaited(CloudSyncService.removeFavorite(questionId.toString()));
    } else {
      unawaited(CloudSyncService.addFavorite(questionId.toString()));
    }
  }

  // ── Study Progress ──────────────────────────────────────────

  Future<Map<int, Map<String, int>>> getProgress() => _store.getProgress();

  Future<void> updateProgress(
          int chapterId, int answered, int correct) =>
      _store.updateProgress(chapterId, answered, correct);

  // ── Exam Record ─────────────────────────────────────────────

  Future<List<ExamRecord>> getExamRecords() async {
    final raw = await _store.getExamRecordsRaw();
    return raw
        .asMap()
        .entries
        .map((e) => ExamRecord.fromMap({...e.value, 'id': e.key}))
        .toList();
  }

  Future<void> saveExamRecord(ExamRecord record) =>
      _store.saveExamRecord(record.toMap());
}
