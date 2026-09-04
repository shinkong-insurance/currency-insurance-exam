import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:currency_insurance_exam/features/guide/guide_viewer_page.dart';

void main() {
  testWidgets('shows a message when the chapter has no guide pages',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: GuideViewerPage(chapterId: 999, chapterTitle: 'Ch999'),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('本章尚無簡報頁面'), findsOneWidget);
  });
}
