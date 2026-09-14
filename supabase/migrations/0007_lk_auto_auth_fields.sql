-- supabase/migrations/0007_lk_auto_auth_fields.sql
-- #/lk 自動授權：填「姓名/單位/員編」三欄即可取得 60 天授權，比照壽險版
-- insurance-exam-app 的 lk-auto-authorization 設計，但外幣版沒有電話/推薦人
-- 概念，改用「姓名+單位+員編」三欄組合辨識同一人（見 auto-register-student
-- Edge Function）。

alter table public.students
  add column if not exists employee_id text;

-- Non-unique: this is a lookup-speed index for the "same person = same
-- name+unit_name+employee_id" rule, which is enforced in application code
-- (auto-register-student Edge Function), not the database.
create index if not exists students_name_unit_employee_idx
  on public.students (name, unit_name, employee_id);
