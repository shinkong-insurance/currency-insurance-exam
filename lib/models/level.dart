class Level {
  final int id, order, chapterId;
  final String label;
  final List<int> questionIds;
  final double passThreshold;
  const Level({required this.id, required this.order, required this.label,
      required this.chapterId, required this.questionIds, required this.passThreshold});

  factory Level.fromMap(Map<String, dynamic> m) => Level(
    id: m['id'], order: m['order'], label: m['label'], chapterId: m['chapter_id'],
    questionIds: List<int>.from(m['question_ids']),
    passThreshold: (m['pass_threshold'] as num).toDouble(),
  );
}
