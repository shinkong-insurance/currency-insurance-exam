-- supabase/migrations/0004_add_notes_to_license_keys.sql
-- 後台 web/admin.html「授權碼管理」分頁的新增/編輯授權碼表單有一個「備註」欄位
-- （saveKey() 的 payload 會送 notes），但 0001_init_schema.sql 當初設計
-- license_keys 表時沒有這個欄位（Flutter app 完全不用它）。這裡補上，
-- 單純是後台管理用的自由備註，nullable，不影響任何既有資料或 app 邏輯。
alter table license_keys add column notes text;
