import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/level_provider.dart';

class LevelMapPage extends ConsumerWidget {
  const LevelMapPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelsAsync = ref.watch(levelsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('18 關卡地圖')),
      body: levelsAsync.when(
        data: (levels) => ListView(
          shrinkWrap: true,
          children: levels.map((lvl) {
            final passedAsync = ref.watch(levelPassedProvider(lvl.id));
            return ListTile(
              enabled: true, // 軟解鎖：一律可點
              leading: Text(passedAsync.valueOrNull == true ? '🟢' : '⚪',
                  style: const TextStyle(fontSize: 20)),
              title: Text(lvl.label, style: const TextStyle(fontSize: 18)),
              onTap: () => context.push('/quiz/0?levelId=${lvl.id}'),
            );
          }).toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('讀取失敗:$e')),
      ),
    );
  }
}
