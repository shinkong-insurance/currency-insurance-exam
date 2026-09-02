class Chapter {
  final int id;
  final int courseId;
  final int unitNo;
  final String title;
  final String weight;

  const Chapter({
    required this.id,
    required this.courseId,
    required this.unitNo,
    required this.title,
    required this.weight,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    id: json['id'],
    courseId: json['courseId'],
    unitNo: json['unitNo'],
    title: json['title'],
    weight: json['weight'],
  );

  factory Chapter.fromSupabaseRow(Map<String, dynamic> row) => Chapter(
    id: row['id'],
    courseId: row['course_id'],
    unitNo: row['unit_no'],
    title: row['title'],
    weight: row['weight'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'unitNo': unitNo,
    'title': title,
    'weight': weight,
  };
}
