import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:currency_insurance_exam/features/guide/guide_viewer_page.dart';

void main() {
  testWidgets('next/prev buttons page through images and disable at bounds',
      (tester) async {
    // chapter 1 (外幣保險開放紀事) spans pages 1-15 in guide_pages.json = 15 pages
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: GuideViewerPage(chapterId: 1, chapterTitle: 'Ch1'),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('第 1 頁 / 共 15 頁'), findsOneWidget);

    final prevButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(prevButton.onPressed, isNull); // disabled on first page

    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('第 2 頁 / 共 15 頁'), findsOneWidget);
  });
}
