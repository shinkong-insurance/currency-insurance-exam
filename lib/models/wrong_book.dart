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

  // 用純日期（不含時分秒）比較：nextReviewDate <= 今天才算到期。
  // 原本寫成 DateTime.now().add(Duration(days: 1)) 會讓「排到明天」的題目
  // 幾乎整天都被誤判成「今天就到期」（因為 nextReviewDate 解析出來是明天
  // 00:00:00，而比較基準是明天的當下時刻，前者幾乎必然早於後者）——等於
  // 才剛答錯排到隔天複習，馬上又被算進今日待複習，完全違背間隔複習的用意。
  bool get isDue {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    return !DateTime.parse(nextReviewDate).isAfter(todayMidnight);
  }
}
