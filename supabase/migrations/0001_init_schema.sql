-- supabase/migrations/0001_init_schema.sql
create extension if not exists "uuid-ossp";

create table course (
  id int primary key,
  name text not null,
  description text
);

create table chapters (
  id int primary key,
  course_id int not null references course(id),
  unit_no int not null,   -- 對應既有 Chapter model 的 unitNo（沿用其欄位，不改 model）
  title text not null,
  weight text not null default ''  -- 沿用既有 Chapter model 的 weight 欄位；外幣版無章節配分資料，固定空字串
);

create table questions (
  id int primary key,
  chapter_id int not null references chapters(id),
  question_no int not null,
  question text not null,
  options text[] not null,
  answer int not null check (answer between 1 and 4),
  explanation text not null default '',
  keyword_hint text,
  plain_explanation text,
  plain_explanation_reviewed boolean not null default false,
  textbook_page int,
  exam_set text  -- 原始 A/B/C/D/E/新增 卷別，供內容追溯
);

create table mnemonic_cards (
  id uuid primary key default uuid_generate_v4(),
  chapter_id int not null references chapters(id),
  phrase text not null,
  meaning text[] not null,
  source text not null check (source in ('original', 'ai_generated')),
  approved boolean not null default false,
  related_question_ids int[] not null default '{}'
);

create table sections (
  id int primary key,
  chapter_id int not null references chapters(id),
  "order" int not null,
  title text not null,
  content text not null
);

create table levels (
  id int primary key,
  "order" int not null,
  label text not null,
  chapter_id int not null references chapters(id),
  question_ids int[] not null,
  pass_threshold numeric not null default 0.7
);

-- 以下 license_keys / key_sessions / key_favorites / key_wrong_answers 的表名與欄位，
-- 逐字對照 lib/core/services/lk_auth_service.dart 與 cloud_sync_service.dart
-- 實際查詢的欄位（.select/.eq/.insert/.update 用到的每一個名字），不是新設計。
create table license_keys (
  id uuid primary key default uuid_generate_v4(),
  key_code text unique not null,
  batch_name text,
  max_uses int not null default 1,      -- 0 = 無限
  used_count int not null default 0,
  expires_at timestamptz not null,
  is_active boolean not null default true
);

create table key_sessions (
  id uuid primary key default uuid_generate_v4(),
  key_id uuid not null references license_keys(id) on delete cascade,
  device_id text not null,
  login_count int not null default 1,
  last_used_at timestamptz,
  unique (key_id, device_id)
);

-- lk_auth_service.dart 用 _sb.rpc('increment_key_used_count', params: {'k_id': keyId}) 呼叫
create or replace function increment_key_used_count(k_id uuid)
returns void as $$
  update license_keys set used_count = used_count + 1 where id = k_id;
$$ language sql;

create table key_favorites (
  key_id uuid not null references license_keys(id) on delete cascade,
  device_id text not null,
  question_id text not null,   -- CloudSyncService 的方法簽名是 String questionId，這裡沿用 text，不對 questions(id) 建 FK（int 與 text 型別不同）
  created_at timestamptz not null default now(),
  unique (key_id, device_id, question_id)
);

create table key_wrong_answers (
  key_id uuid not null references license_keys(id) on delete cascade,
  device_id text not null,
  question_id text not null,
  wrong_count int not null default 1,
  last_wrong_at timestamptz not null default now(),
  correct_streak int not null default 0,               -- 新增（spec §8.4）
  next_review_date date not null default (current_date + 1),  -- 新增（spec §8.4）
  unique (key_id, device_id, question_id)
);

create table level_progress (
  key_id uuid not null references license_keys(id) on delete cascade,
  device_id text not null,
  level_id int not null references levels(id),
  attempted int not null default 0,
  correct int not null default 0,
  passed boolean not null default false,
  last_attempt_at timestamptz,
  primary key (key_id, device_id, level_id)
);

-- study_logger.dart 的 _insert() 直接把這些欄位當頂層物件送出（不是包在 jsonb 裡），
-- 只有 quizSession() 的 meta 這個小物件真的走 jsonb metadata 欄位。
create table study_logs (
  id uuid primary key default uuid_generate_v4(),
  license_key text not null,    -- 存的是 key_code（StudyLogger._getLicenseKey 回傳 session.keyCode）
  event_type text not null,
  chapter_id text,
  section_id text,
  duration_seconds int,
  questions_total int,
  questions_correct int,
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- RLS：內容表(course/chapters/questions/sections/levels/mnemonic_cards)對外唯讀。
-- license_keys/key_sessions/key_favorites/key_wrong_answers/level_progress/study_logs
-- 刻意不加 RLS ownership 限制：既有 lk_auth_service.dart / cloud_sync_service.dart 全程
-- 用 anon key + 純 .eq('key_id', ...) 過濾，沒有任何 Supabase Auth session 或 JWT claim
-- 可以讓 RLS 驗證「這個 key_id 真的屬於呼叫端」——加上去只會讓現有程式碼直接打不通。
-- 這是沿用既有壽險 app 的信任模型，等於任何持有 anon key 又猜得到 key_id+device_id 的人
-- 理論上就能讀寫該筆資料。這一點連同壽險本身的既有風險一併記錄在 ledger，交給你決定
-- 要不要之後另外設計驗證機制強化，不在本次任務範圍內處理。
alter table questions enable row level security;
alter table mnemonic_cards enable row level security;
alter table sections enable row level security;
alter table levels enable row level security;
alter table chapters enable row level security;
alter table course enable row level security;

create policy "content readable by anon" on questions for select using (true);
create policy "content readable by anon" on mnemonic_cards for select using (approved = true);
create policy "content readable by anon" on sections for select using (true);
create policy "content readable by anon" on levels for select using (true);
create policy "content readable by anon" on chapters for select using (true);
create policy "content readable by anon" on course for select using (true);
