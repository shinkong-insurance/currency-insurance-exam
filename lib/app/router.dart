// lib/app/router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/services/lk_auth_service.dart';
import '../features/auth/lk_gate_page.dart';
import '../features/auth/license_expired_page.dart';
import '../features/home/home_page.dart';
import '../features/chapter/chapter_list_page.dart';
import '../features/chapter/chapter_detail_page.dart';
import '../features/section/section_reading_page.dart';
import '../features/quiz/quiz_page.dart';
import '../features/levels/level_map_page.dart';
import '../features/mnemonics/mnemonic_card_list_page.dart';
import '../features/exam/exam_page.dart';
import '../features/exam/exam_result_page.dart';
import '../features/wrongbook/wrong_book_page.dart';
import '../features/favorite/favorite_page.dart';
import '../features/progress/progress_page.dart';

// ──────────────────────────────────────────────
// 授權守衛（授權碼登入）
// ──────────────────────────────────────────────
Future<String?> _authGuard(BuildContext context, GoRouterState state) async {
  final loc = state.matchedLocation;

  // 免驗證頁面直接放行
  if (loc == '/lk' || loc == '/expired') return null;

  // 授權碼版 session
  final lkSession = await LkAuthService.getSession();
  if (lkSession != null) return null;

  // 無 session → 導向授權碼登入頁
  return '/lk';
}

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: _authGuard,
  routes: [
    // ── 授權頁 ──────────────────────────────
    GoRoute(path: '/lk', builder: (_, __) => const LkGatePage()),
    GoRoute(
      path: '/expired',
      builder: (_, state) => LicenseExpiredPage(
        message: state.uri.queryParameters['msg'] ?? '使用期限已到，請聯絡管理員',
      ),
    ),

    // ── 主功能頁 ────────────────────────────
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/chapters', builder: (_, __) => const ChapterListPage()),
    GoRoute(
      path: '/chapter/:chapterId',
      builder: (_, state) => ChapterDetailPage(
        chapterId: int.parse(state.pathParameters['chapterId']!),
      ),
    ),
    GoRoute(
      path: '/section/:chapterId/:sectionId',
      builder: (_, state) => SectionReadingPage(
        chapterId: int.parse(state.pathParameters['chapterId']!),
        sectionId: int.parse(state.pathParameters['sectionId']!),
      ),
    ),
    GoRoute(
      path: '/quiz/:chapterId',
      builder: (_, state) => QuizPage(
        chapterId: int.parse(state.pathParameters['chapterId']!),
        isWrongBook: state.uri.queryParameters['wrong'] == 'true',
        isFavorite: state.uri.queryParameters['fav'] == 'true',
        isReviewMode: state.uri.queryParameters['review'] == 'true',
        levelId: state.uri.queryParameters['levelId'] != null
            ? int.parse(state.uri.queryParameters['levelId']!)
            : null,
      ),
    ),
    GoRoute(
      path: '/exam',
      builder: (_, state) => ExamPage(
        count: int.parse(state.uri.queryParameters['count'] ?? '50'),
        chapterId: state.uri.queryParameters['chapter'] != null
            ? int.parse(state.uri.queryParameters['chapter']!)
            : null,
        courseId: state.uri.queryParameters['courseId'] != null
            ? int.parse(state.uri.queryParameters['courseId']!)
            : null,
        wrongPriority: state.uri.queryParameters['wrongPriority'] == 'true',
        paperName: state.uri.queryParameters['paper'],
      ),
    ),
    GoRoute(
      path: '/exam-result',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ExamResultPage(result: extra);
      },
    ),
    GoRoute(path: '/levels', builder: (_, __) => const LevelMapPage()),
    GoRoute(path: '/mnemonics', builder: (_, __) => const MnemonicCardListPage()),
    GoRoute(path: '/wrongbook', builder: (_, __) => const WrongBookPage()),
    GoRoute(path: '/favorite', builder: (_, __) => const FavoritePage()),
    GoRoute(path: '/progress', builder: (_, __) => const ProgressPage()),
  ],
);
