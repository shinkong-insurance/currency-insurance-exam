class Question {
  final int id;
  final int chapterId;
  final int questionNo;
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;
  final String? keywordHint;
  final String? plainExplanation;
  final int? textbookPage;

  const Question({
    required this.id,
    required this.chapterId,
    required this.questionNo,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.keywordHint,
    this.plainExplanation,
    this.textbookPage,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'],
    chapterId: json['chapterId'],
    questionNo: json['questionNo'],
    question: json['question'],
    options: List<String>.from(json['options']),
    answer: json['answer'],
    explanation: json['explanation'] ?? '',
  );

  /// `plain_explanation` 只有在 `plain_explanation_reviewed` 為 true 時才會被
  /// 帶進 model，未審核的草稿一律當成不存在（UI 端的顯示條件是
  /// `plainExplanation != null`，見 ExplanationPanel）。
  ///
  /// 這道閘門刻意放在這個唯一的轉換點，而不是各個呼叫端：
  ///   * `questions` 的 RLS policy 是 row-level 的（`using (true)`），沒辦法像
  ///     `mnemonic_cards` 的 `approved = true` 那樣只遮一個欄位——把整列遮掉會
  ///     連題目本身都不見；要在 DB 層做就得改成 security_invoker view 並讓
  ///     client 改讀 view，那是另一個 migration 的範圍。
  ///   * 快取層（ContentCacheStore）存的是原始 row，也會經過這裡，所以離線讀
  ///     取同樣受閘門保護。
  ///   * 欄位缺失（例如舊版快取沒有這個 key）時 `== true` 會是 false，
  ///     預設是「不顯示」，fail-closed。
  factory Question.fromSupabaseRow(Map<String, dynamic> row) => Question(
    id: row['id'],
    chapterId: row['chapter_id'],
    questionNo: row['question_no'],
    question: row['question'],
    options: List<String>.from(row['options']),
    answer: row['answer'],
    explanation: row['explanation'] ?? '',
    keywordHint: row['keyword_hint'],
    plainExplanation: row['plain_explanation_reviewed'] == true
        ? row['plain_explanation']
        : null,
    textbookPage: row['textbook_page'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'chapterId': chapterId,
    'questionNo': questionNo,
    'question': question,
    'options': options,
    'answer': answer,
    'explanation': explanation,
  };
}
