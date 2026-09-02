class WrongBook {
  final int? id;
  final int questionId;
  final int wrongCount;
  final int correctStreak;
  final String lastWrongTime;
  final String nextReviewDate;  // ISO 8601 date, e.g. "2026-09-03"

  const WrongBook({
    this.id,
    required this.questionId,
    required this.wrongCount,
    required this.correctStreak,
    required this.lastWrongTime,
    required this.nextReviewDate,
  });

  factory WrongBook.fromMap(Map<String, dynamic> m) => WrongBook(
    id: m['id'],
    questionId: m['question_id'],
    wrongCount: m['wrong_count'],
    correctStreak: m['correct_streak'] ?? 0,
    lastWrongTime: m['last_wrong_time'],
    nextReviewDate: m['next_review_date'] ?? m['last_wrong_time'],
  );

  Map<String, dynamic> toMap() => {
    'question_id': questionId,
    'wrong_count': wrongCount,
    'correct_streak': correctStreak,
    'last_wrong_time': lastWrongTime,
    'next_review_date': nextReviewDate,
  };

  bool get isDue => DateTime.parse(nextReviewDate).isBefore(
      DateTime.now().add(const Duration(days: 1)));
}
