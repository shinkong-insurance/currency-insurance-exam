class MnemonicCard {
  final String id;
  final int chapterId;
  final String phrase;
  final List<String> meaning;
  final String source;
  const MnemonicCard({required this.id, required this.chapterId,
      required this.phrase, required this.meaning, required this.source});

  factory MnemonicCard.fromMap(Map<String, dynamic> m) => MnemonicCard(
    id: m['id'], chapterId: m['chapter_id'], phrase: m['phrase'],
    meaning: List<String>.from(m['meaning']), source: m['source'],
  );
}
