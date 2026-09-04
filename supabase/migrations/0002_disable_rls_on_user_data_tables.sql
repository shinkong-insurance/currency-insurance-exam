-- supabase/migrations/0002_disable_rls_on_user_data_tables.sql
--
-- 0001_init_schema.sql 原本刻意不對 license_keys/key_sessions/key_favorites/
-- key_wrong_answers/level_progress/study_logs 這幾張表加 RLS（理由寫在該檔案
-- 的註解裡：既有 lk_auth_service.dart / cloud_sync_service.dart 全程用 anon
-- key + 純 .eq() 過濾，沒有 Supabase Auth session 可以讓 RLS 驗證呼叫端身分，
-- 加上去只會讓現有程式碼打不通）。
--
-- 但實測（2026-09-04，真的申請新 Supabase 專案上線時）發現：新建立的
-- Supabase 專案現在會預設對新表開啟 RLS（平台行為，跟這份 schema 原本設計
-- 時的預設值不同），而「不開 RLS」的表一旦被平台自動開了 RLS 又沒有任何
-- policy，效果等同全部擋掉——anon key 完全讀不到 license_keys，登入流程
-- 直接卡死在「找不到此授權碼」。這裡明確關掉 RLS，讓實際行為對回
-- 0001 原本的設計意圖，不是新的安全決策。
alter table license_keys disable row level security;
alter table key_sessions disable row level security;
alter table key_favorites disable row level security;
alter table key_wrong_answers disable row level security;
alter table level_progress disable row level security;
alter table study_logs disable row level security;
