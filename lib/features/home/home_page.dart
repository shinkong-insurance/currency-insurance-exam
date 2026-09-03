import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_data_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/section_provider.dart';
import '../../core/open_url.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrongIds = ref.watch(wrongIdsProvider);
    final favIds = ref.watch(favoriteIdsProvider);
    final allQs = ref.watch(allQuestionsProvider);
    final allSecs = ref.watch(allSectionsProvider);
    final chapters = ref.watch(chaptersProvider);

    final totalQ = allQs.maybeWhen(data: (q) => q.length, orElse: () => 942);
    final totalSecs =
        allSecs.maybeWhen(data: (s) => s.length, orElse: () => 60);
    final totalChapters =
        chapters.maybeWhen(data: (c) => c.length, orElse: () => 8);
    final wrongCount =
        wrongIds.maybeWhen(data: (w) => w.length, orElse: () => 0);
    final favCount = favIds.maybeWhen(data: (f) => f.length, orElse: () => 0);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('外幣保險考照',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.tertiary,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 52),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.school,
                              size: 36, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$totalChapters 章 $totalSecs 節教材',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('$totalQ 道精選題庫',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 使用手冊入口
                const _ManualBanner(),
                const SizedBox(height: 12),
                // 今日待複習徽章
                Consumer(builder: (context, ref, _) {
                  final due = ref.watch(dueReviewCountProvider);
                  return due.when(
                    data: (count) => count > 0
                        ? Card(
                            child: ListTile(
                              leading: const Text('📌',
                                  style: TextStyle(fontSize: 24)),
                              title: Text('今日待複習 $count 題',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              onTap: () => context.push('/quiz/0?review=true'),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                }),
                const SizedBox(height: 12),
                // Stats row
                Row(
                  children: [
                    _StatCard(
                        label: '題庫',
                        value: '$totalQ',
                        icon: Icons.library_books,
                        color: Colors.blue),
                    const SizedBox(width: 8),
                    _StatCard(
                        label: '錯題',
                        value: '$wrongCount',
                        icon: Icons.error_outline,
                        color: Colors.red),
                    const SizedBox(width: 8),
                    _StatCard(
                        label: '收藏',
                        value: '$favCount',
                        icon: Icons.bookmark,
                        color: Colors.amber),
                    const SizedBox(width: 8),
                    _StatCard(
                        label: '章節',
                        value: '$totalChapters',
                        icon: Icons.menu_book,
                        color: Colors.green),
                  ],
                ),
                const SizedBox(height: 24),

                // ── 學習教材 ──────────────────────────────────
                _SectionHeader(title: '學習教材與練習', icon: Icons.auto_stories),
                const SizedBox(height: 10),
                _FeatureCard(
                  icon: Icons.menu_book,
                  title: '章節閱讀',
                  subtitle: '$totalChapters 章 $totalSecs 節系統教材，條理清晰',
                  color: const Color(0xFF1565C0),
                  onTap: () => context.push('/chapters'),
                ),
                _FeatureCard(
                  icon: Icons.map,
                  title: '18 關卡地圖',
                  subtitle: '闖關學習，依章節分關卡練習，隨時可挑戰任何一關',
                  color: Colors.teal,
                  onTap: () => context.push('/levels'),
                ),
                _FeatureCard(
                  icon: Icons.lightbulb_outline,
                  title: '口訣卡',
                  subtitle: '精選記憶口訣，濃縮重點好記好背',
                  color: Colors.purple,
                  onTap: () => context.push('/mnemonics'),
                ),
                const SizedBox(height: 20),

                // ── 題庫練習 ──────────────────────────────────
                _SectionHeader(title: '題庫練習', icon: Icons.quiz),
                const SizedBox(height: 10),
                _FeatureCard(
                  icon: Icons.timer,
                  title: '模擬測驗',
                  subtitle: '隨機抽題 · 綜合測驗',
                  color: Colors.orange,
                  onTap: () => context.push('/exam?count=50'),
                ),
                const SizedBox(height: 20),

                // ── 複習功能 ──────────────────────────────────
                _SectionHeader(title: '複習功能', icon: Icons.replay),
                const SizedBox(height: 10),
                _FeatureCard(
                  icon: Icons.error_outline,
                  title: '錯題本',
                  subtitle:
                      wrongCount > 0 ? '共 $wrongCount 題需複習' : '目前沒有錯題，繼續加油！',
                  color: Colors.red,
                  badge: wrongCount > 0 ? '$wrongCount' : null,
                  onTap:
                      wrongCount > 0 ? () => context.push('/wrongbook') : null,
                ),
                _FeatureCard(
                  icon: Icons.bookmark,
                  title: '收藏題目',
                  subtitle: favCount > 0 ? '已收藏 $favCount 題' : '尚未收藏任何題目',
                  color: Colors.amber,
                  badge: favCount > 0 ? '$favCount' : null,
                  onTap: favCount > 0 ? () => context.push('/favorite') : null,
                ),
                _FeatureCard(
                  icon: Icons.bar_chart,
                  title: '學習進度',
                  subtitle: '查看各章節答題統計與正確率',
                  color: Colors.green,
                  onTap: () => context.push('/progress'),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: (enabled ? color : Colors.grey).withOpacity(0.15),
          child: Icon(icon, color: enabled ? color : Colors.grey),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: enabled ? null : Colors.grey)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: badge != null
            ? Badge(label: Text(badge!), child: const Icon(Icons.chevron_right))
            : Icon(Icons.chevron_right,
                color: enabled ? null : Colors.grey[300]),
        onTap: onTap,
        enabled: enabled,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 使用手冊快速入口
// ──────────────────────────────────────────────
class _ManualBanner extends StatelessWidget {
  const _ManualBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.12),
            cs.tertiary.withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.menu_book_outlined, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('考生使用手冊',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 2),
                Text('APP 功能介紹 · 操作說明 · 考試資訊',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => openUrl('student-guide.html'),
            icon: const Icon(Icons.open_in_new, size: 15),
            label: const Text('查看', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}
