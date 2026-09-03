import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/question_provider.dart';
import '../../providers/section_provider.dart';
import '../../providers/user_data_provider.dart';
import '../../models/chapter.dart';

class ChapterListPage extends ConsumerWidget {
  const ChapterListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider);
    final allQsAsync = ref.watch(allQuestionsProvider);
    final allSecAsync = ref.watch(allSectionsProvider);
    final progressAsync = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('章節學習'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: _TabHint(),
        ),
      ),
      body: chaptersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗: $e')),
        data: (chapters) {
          final allQs = allQsAsync.valueOrNull ?? [];
          final allSecs = allSecAsync.valueOrNull ?? [];
          final progress = progressAsync.valueOrNull ?? {};

          // 本 APP 的章節結構是扁平的 8 個主題（spec §3），沒有「單元」概念；
          // schema 中的 unitNo 是逐章設成 chapter_id（見 scripts/seed/seed_content.py），
          // 所以不做任何分組，直接依 id 排序後平鋪呈現。
          final sorted = [...chapters]..sort((a, b) => a.id.compareTo(b.id));

          return ListView(
            children: [
              ..._buildChapterTiles(
                  context, sorted, allQs, allSecs, progress,
                  const Color(0xFF1565C0)),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildChapterTiles(
    BuildContext context,
    List<Chapter> chapters,
    List allQs,
    List allSecs,
    Map<int, Map<String, int>> progress,
    Color color,
  ) {
    return chapters.map((chapter) {
      final qCount = allQs.where((q) => q.chapterId == chapter.id).length;
      final secCount = allSecs.where((s) => s.chapterId == chapter.id).length;
      final prog = progress[chapter.id];
      final answered = prog?['answered'] ?? 0;
      final correct = prog?['correct'] ?? 0;
      final pct = qCount > 0 ? answered / qCount : 0.0;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/chapter/${chapter.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text(
                        '${chapter.id % 100}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(chapter.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _Chip(
                                icon: Icons.menu_book,
                                label: '$secCount 節',
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              _Chip(
                                icon: Icons.quiz,
                                label: '$qCount 題',
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              _Chip(
                                icon: Icons.bar_chart,
                                label: chapter.weight,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                if (answered > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: color.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$correct/$qCount 正確',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _TabHint extends StatelessWidget {
  const _TabHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        '點擊章節可查看教材與練習題',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
