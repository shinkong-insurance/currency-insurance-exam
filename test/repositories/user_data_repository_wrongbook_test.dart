import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:currency_insurance_exam/repositories/user_data_repository.dart';

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

  test('getDueWrongQuestionIds returns only due question ids', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1); // next_review_date = 明天，今天視為到期
    final ids = await repo.getDueWrongQuestionIds();
    expect(ids, contains(1));
  });
}
