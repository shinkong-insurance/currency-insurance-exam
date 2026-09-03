// lib/core/services/supabase_config.dart
// Supabase 連線設定（考照 APP 專用）
//
// ⚠️ 這兩個值必須在 build 時以 --dart-define（或 --dart-define-from-file）提供，
// 例如：
//
//   flutter build web \
//     --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
//
// 或使用檔案：
//
//   flutter run --dart-define-from-file=env/supabase.json
//
// 本 APP 需要「新的 Supabase 專案（不共用壽險那個）」(spec §4)。在該專案尚未
// 建立前，這裡刻意使用明顯無效的佔位字串，讓未設定 dart-define 的 build 立即
// 失敗，而不是靜默連上別的 APP 的正式資料庫。
//
// 注意：Python 種子腳本（scripts/seed/*.py）走的是另一套機制（環境變數
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY），不受此檔影響。

const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://REPLACE_ME.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'REPLACE_ME',
);
