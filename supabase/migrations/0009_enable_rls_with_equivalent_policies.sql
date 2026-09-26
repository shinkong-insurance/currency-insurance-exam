-- supabase/migrations/0009_enable_rls_with_equivalent_policies.sql
--
-- 2026-09-26 例行檢查：Supabase Security Advisor 對以下 5 張表報 ERROR
-- 「RLS Disabled in Public」。0002 刻意關掉 RLS（學員端全程用 anon key，
-- 沒有 Auth session）。這裡改成「開 RLS + 等效的全開 policy」，
-- 學員端與後台（authenticated admin）行為完全不變，只是消除 ERROR，
-- 並與人身壽險（LIFE）專案的寫法一致。
--
-- 另外：anon / authenticated 原本對所有 public 表都有 TRUNCATE 權限。
-- TRUNCATE 不受 RLS 限制、PostgREST 也用不到，收回以防萬一。
-- license_keys 不在此列（0008 已開 RLS）。
do $$
declare t text;
begin
  foreach t in array array['key_sessions','key_favorites','key_wrong_answers','level_progress','study_logs'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists client_all on public.%I', t);
    execute format('create policy client_all on public.%I for all to anon, authenticated using (true) with check (true)', t);
  end loop;
end $$;

revoke truncate on all tables in schema public from anon, authenticated;
