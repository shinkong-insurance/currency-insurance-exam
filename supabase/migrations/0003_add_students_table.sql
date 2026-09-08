-- supabase/migrations/0003_add_students_table.sql
-- 學員名冊表：對應後台 web/admin.html 的「學員管理」分頁（姓名/區部/單位/信箱、
-- 授權碼指派狀態、寄送 Email 通知記錄）。逐欄對照壽險版 insurance-exam-app 的
-- web/admin.html 實際查詢用到的欄位，不是新設計。純後台管理用途，
-- Flutter app（lib/）不讀寫這張表。
create table students (
  id uuid primary key default uuid_generate_v4(),
  region text,
  unit_name text,
  name text not null,
  email text,
  batch_name text,
  key_id uuid references license_keys(id),
  key_code text,
  expires_at timestamptz,
  notes text,
  is_active boolean not null default true,
  email_sent_at timestamptz,
  created_at timestamptz not null default now()
);

-- 沿用 0001/0002 對 license_keys 等表的信任模型：後台 admin.html 全程用 anon key
-- 直接讀寫，沒有 Supabase Auth session 可以驗證「這個 student row 真的屬於呼叫端」，
-- RLS policy 加了也只會擋掉現有 admin.html 的正常操作。新專案對新建表預設會自動
-- 開啟 RLS（見 docs/DEPLOYMENT_RUNBOOK.md 2026-09-04 段落問題 1），這裡明確關閉，
-- 呼應 0002 對其他 6 張使用者資料表做的事。
alter table students disable row level security;
