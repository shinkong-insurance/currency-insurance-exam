import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/database/shared_preferences_store.dart';
import 'core/services/supabase_config.dart';
import 'core/services/cloud_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final store = SharedPreferencesStore.instance;
  final prefs = await store.prefs;

  if (kIsWeb) {
    // 初始化 CloudSyncService（確認是否為 LK 模式）
    final isLkMode = await CloudSyncService.init();

    if (isLkMode) {
      // ── LK 模式：從 Supabase 拉取收藏/錯題到本地 ──
      await _pullCloudDataToLocal(store);
    } else {
      // ── 非 LK 模式：每次開啟清除學習資料 ──
      // 'fx_' 前綴：跟 shared_preferences_store.dart 用的 key 要完全一致
      // （見該檔案開頭的說明），這裡是直接操作 SharedPreferences 而非透過
      // SharedPreferencesStore 的方法，所以沒辦法共用同一份常數定義，
      // 前綴打錯會讓這裡清不到真正的資料。
      await prefs.remove('fx_wrong_book');
      await prefs.remove('fx_favorites');
      await prefs.remove('fx_study_progress');
      await prefs.remove('fx_exam_records');
    }
  }

  runApp(const ProviderScope(child: InsuranceExamApp()));
}

/// 從 Supabase 拉取並合併到本地 SharedPreferences（啟動時執行一次）
Future<void> _pullCloudDataToLocal(SharedPreferencesStore store) async {
  try {
    // ── 收藏 ──────────────────────────────────
    final cloudFavStrings = await CloudSyncService.fetchFavorites();
    if (cloudFavStrings.isNotEmpty) {
      final localFavs = (await store.getFavoriteIds()).toSet();
      final cloudFavInts = cloudFavStrings
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toSet();
      final merged = {...localFavs, ...cloudFavInts}.toList();
      final p = await store.prefs;
      await p.setString('fx_favorites', json.encode(merged));
    }

    // ── 錯題 ──────────────────────────────────
    final cloudWrong = await CloudSyncService.fetchWrongAnswers();
    if (cloudWrong.isNotEmpty) {
      final localWrong = await store.getWrongBook();
      for (final entry in cloudWrong.entries) {
        final key = entry.key;       // question_id 字串
        final count = entry.value;   // wrong_count
        if (!localWrong.containsKey(key) ||
            (localWrong[key]['wrong_count'] as int) < count) {
          localWrong[key] = {
            'question_id': int.tryParse(key) ?? 0,
            'wrong_count': count,
            'last_wrong_time': DateTime.now().toIso8601String(),
          };
        }
      }
      final p = await store.prefs;
      await p.setString('fx_wrong_book', json.encode(localWrong));
    }
  } catch (_) {
    // 拉取失敗不影響 App 啟動
  }
}
