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

  factory Question.fromSupabaseRow(Map<String, dynamic> row) => Question(
    id: row['id'],
    chapterId: row['chapter_id'],
    questionNo: row['question_no'],
    question: row['question'],
    options: List<String>.from(row['options']),
    answer: row['answer'],
    explanation: row['explanation'] ?? '',
    keywordHint: row['keyword_hint'],
    plainExplanation: row['plain_explanation'],
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
