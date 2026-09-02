import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:currency_insurance_exam/repositories/user_data_repository.dart';
import 'package:currency_insurance_exam/models/wrong_book.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('wrong answer resets streak and schedules review for tomorrow', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    final books = await repo.getWrongBooks();
    expect(books.first.correctStreak, 0);
    final expected = DateTime.now().add(const Duration(days: 1));
    expect(DateTime.parse(books.first.nextReviewDate).day, expected.day);
  });

  test('first correct review answer bumps streak and reschedules +3 days, stays in wrong book', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    await repo.markReviewedCorrect(1);
    final books = await repo.getWrongBooks();
    expect(books.length, 1);
    expect(books.first.correctStreak, 1);
    final expected = DateTime.now().add(const Duration(days: 3));
    expect(DateTime.parse(books.first.nextReviewDate).day, expected.day);
  });

  test('second consecutive correct review answer clears the question from wrong book', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    await repo.markReviewedCorrect(1);
    await repo.markReviewedCorrect(1);
    final books = await repo.getWrongBooks();
    expect(books, isEmpty);
  });

  test('a wrong answer mid-review resets streak instead of clearing', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    await repo.markReviewedCorrect(1);
    await repo.markReviewedWrong(1);
    final books = await repo.getWrongBooks();
    expect(books.first.correctStreak, 0);
  });

  test('normal practice mode answering correctly does not touch the streak', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    await repo.recordPracticeAnswer(1, correct: true); // 一般練習作答，非複習模式
    final books = await repo.getWrongBooks();
    expect(books.first.correctStreak, 0);
  });

  test('isDue is true only when nextReviewDate is today or earlier', () {
    final today = DateTime.now();
    String dateStr(int offsetDays) =>
        today.add(Duration(days: offsetDays)).toIso8601String().substring(0, 10);

    final dueToday = WrongBook(questionId: 1, wrongCount: 1, correctStreak: 0,
        lastWrongTime: today.toIso8601String(), nextReviewDate: dateStr(0));
    final dueYesterday = WrongBook(questionId: 2, wrongCount: 1, correctStreak: 0,
        lastWrongTime: today.toIso8601String(), nextReviewDate: dateStr(-1));
    final notDueTomorrow = WrongBook(questionId: 3, wrongCount: 1, correctStreak: 0,
        lastWrongTime: today.toIso8601String(), nextReviewDate: dateStr(1));

    expect(dueToday.isDue, true);
    expect(dueYesterday.isDue, true);
    expect(notDueTomorrow.isDue, false);
  });

  test('getDueWrongQuestionIds excludes a question freshly scheduled for tomorrow', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1); // next_review_date = 明天，今天還不算到期
    final ids = await repo.getDueWrongQuestionIds();
    expect(ids, isNot(contains(1)));
  });
}
