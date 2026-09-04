import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Guide page-range map provider ──────────────────────────────────────────
// assets/json/guide_pages.json: {"intro": {...}, "chapters": {"<chapterId>": {"pages":[...],"label":...}}}
final guidePagesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final raw = await rootBundle.loadString('assets/json/guide_pages.json');
  return json.decode(raw) as Map<String, dynamic>;
});

class GuideViewerPage extends ConsumerStatefulWidget {
  final int chapterId;
  final String? chapterTitle;

  const GuideViewerPage({
    super.key,
    required this.chapterId,
    this.chapterTitle,
  });

  @override
  ConsumerState<GuideViewerPage> createState() => _GuideViewerPageState();
}

class _GuideViewerPageState extends ConsumerState<GuideViewerPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guideAsync = ref.watch(guidePagesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.chapterTitle ?? '教材簡報',
          style: const TextStyle(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: guideAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
          child: Text('載入失敗: $e', style: const TextStyle(color: Colors.white)),
        ),
        data: (data) {
          final chapters = data['chapters'] as Map<String, dynamic>?;
          final entry = chapters?[widget.chapterId.toString()]
              as Map<String, dynamic>?;
          final pages = (entry?['pages'] as List?)?.cast<int>() ?? const [];

          if (pages.isEmpty) {
            return const Center(
              child: Text('本章尚無簡報頁面', style: TextStyle(color: Colors.white70)),
            );
          }

          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (context, i) {
                    final page = pages[i];
                    final assetPath =
                        'assets/images/guide/guide_p${page.toString().padLeft(3, '0')}.png';
                    return InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildBottomBar(pages.length),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(int total) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              color: Colors.white,
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentIndex > 0
                  ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      )
                  : null,
            ),
            Expanded(
              child: Text(
                '第 ${_currentIndex + 1} 頁 / 共 $total 頁',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            IconButton(
              color: Colors.white,
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentIndex < total - 1
                  ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
