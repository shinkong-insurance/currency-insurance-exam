import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:currency_insurance_exam/features/guide/guide_viewer_page.dart';

void main() {
  testWidgets('shows the chapter page count, title and first page image',
      (tester) async {
    // chapter 2 (保險業辦理外匯業務管理辦法) spans pages 28-50 in guide_pages.json = 23 pages
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: GuideViewerPage(chapterId: 2, chapterTitle: 'Ch2'),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('第 1 頁 / 共 23 頁'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Ch2'), findsOneWidget);
  });
}
