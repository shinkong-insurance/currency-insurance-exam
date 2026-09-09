-- supabase/migrations/0006_add_question_review_gate.sql
-- 準備從 2025 Q1 題庫 PDF 匯入 715 題新題目（分類到現有 8 章、去重後的結果，
-- 見 scripts/extract/output/fx2025q1_classified.json），但這批題目還沒寫
-- 白話解析、分類準確度也還沒人工複核過。questions 表原本沒有任何「草稿/
-- 已審核」機制，一 insert 進去就會透過 anon key 直接被 Flutter app 讀到，
-- 出現在真實考生的練習/模擬考題庫。
--
-- 新增 reviewed 欄位（比照 mnemonic_cards.approved 同樣的既有模式：把
-- RLS policy 從 using(true) 改成 using(reviewed = true)，在資料庫層擋住未
-- 審核內容，不用改 Flutter 任何一行程式碼——所有既有查詢都走同一個
-- SupabaseContentSource.fetchQuestions()，RLS policy 一改全部自動生效）。
-- default true 讓現有 118 題全部維持可見，不受影響。
alter table questions add column reviewed boolean not null default true;

drop policy "content readable by anon" on questions;
create policy "content readable by anon" on questions for select using (reviewed = true);
