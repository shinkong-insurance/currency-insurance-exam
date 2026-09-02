import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_insurance_exam/features/levels/level_map_page.dart';
import 'package:currency_insurance_exam/models/level.dart';
import 'package:currency_insurance_exam/providers/level_provider.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('all 18 levels are tappable regardless of progress (soft unlock)', (tester) async {
    // 18 個關卡在預設 800x600 測試視窗下無法全部進入可視範圍，ListView 只會
    // lazily build 可視範圍內的項目。放大測試視窗高度，確保全部 18 個 ListTile
    // 都被實際 build 出來，測試才能真正驗證「全部關卡皆可點擊」。
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final levels = List.generate(18, (i) => Level(
      id: i + 1, order: i + 1, label: '第$i關', chapterId: 1,
      questionIds: const [1, 2, 3], passThreshold: 0.7,
    ));
    await tester.pumpWidget(ProviderScope(
      overrides: [levelsProvider.overrideWith((ref) async => levels)],
      child: const MaterialApp(home: LevelMapPage()),
    ));
    await tester.pumpAndSettle();

    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(18));
    for (final tile in tiles.evaluate()) {
      final widget = tile.widget as ListTile;
      expect(widget.enabled, isTrue); // 沒有任何關卡因為順序被鎖住
    }
  });

  testWidgets('shows green light only for passed levels', (tester) async {
    final levels = [Level(id: 1, order: 1, label: '第1關', chapterId: 1,
        questionIds: const [1], passThreshold: 0.7)];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        levelsProvider.overrideWith((ref) async => levels),
        levelPassedProvider(1).overrideWith((ref) async => true),
      ],
      child: const MaterialApp(home: LevelMapPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('🟢'), findsOneWidget);
  });
}
