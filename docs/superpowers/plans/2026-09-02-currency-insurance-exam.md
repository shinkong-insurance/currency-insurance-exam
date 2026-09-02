# 外幣保險資格測驗 App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把壽險考照 app(`insurance-exam-app`)的 Flutter Web + LK 授權碼 + 本機優先/雲端同步架構,複製改造成「外幣保險資格測驗」考照練習網頁,內容改為 Supabase 可編輯,並新增口訣卡、關鍵字破題+白話雙解析、18關卡地圖、錯題本間隔複習排程四項新功能。

**Architecture:** 新專案 `currency-insurance-exam`(Flutter Web),沿用壽險版的 LK 登入/本機優先同步模式,但內容來源從靜態 JSON 改為新建的 Supabase 專案資料表。內容產製走「PDF 文字擷取 → 機械式切段(可測試)→ 結構化(含人工覆核關卡)→ 匯入 Supabase」的管線,不做全自動無人審核的內容上線。

**Tech Stack:** Flutter (Dart) + Riverpod + go_router + supabase_flutter + shared_preferences；內容管線用 Python 3(pdftotext/poppler、pytest、supabase-py)。

**Spec:** `/Users/fortune/currency-insurance-exam/docs/superpowers/specs/2026-09-02-currency-insurance-exam-design.md`

## Global Constraints

- 純網頁,不做原生 Android/iOS 打包(spec §1)
- 使用者存取沿用 LK 授權碼綁裝置模式,非公開自由註冊(spec §5)
- 開新的 Supabase 專案,不共用壽險現有專案(spec §4)
- 內容(course/chapters/questions/sections/mnemonic_cards/levels)一律存 Supabase 表,app 啟動抓取+本機快取,不再打包靜態 JSON(spec §6)
- v1 內容編輯用 Supabase 內建 Table Editor,不開發自訂 CMS 介面(spec §6)
- 章節結構固定為「外幣考照八大重點方向」8 個主題,不用官方 5 章(spec §3)
- 18 關卡採軟解鎖:所有關卡隨時可點開練習,答對率 ≥70% 才亮綠燈,不強制順序(spec §8.3)
- 錯題本 streak 只在「複習模式」作答才計入,一般練習答對不影響(spec §8.4)
- `mnemonic_cards.source = "ai_generated"` 的卡片必須經人工覆核標記為 approved 後才能在 app 顯示(spec §8.1、§11)
- 高齡友善:內文字級 ≥16px、文字對比 ≥4.5:1(重要元素 ≥7:1)、行距 1.5–1.8 倍(spec §9)

---

## Task 1: Scaffold repo from insurance-exam-app template

**Files:**
- Copy: `/Users/fortune/insurance-exam-app/{lib,test,web,pubspec.yaml,analysis_options.yaml}` → `/Users/fortune/currency-insurance-exam/`
- Modify: `/Users/fortune/currency-insurance-exam/pubspec.yaml`
- Delete: `/Users/fortune/currency-insurance-exam/assets/json/*.json`(內容改走 Supabase,不再打包)
- Delete: `/Users/fortune/currency-insurance-exam/android`(未使用的 scaffold,壽險版也從未真的建置發佈)

**Interfaces:**
- Produces: 一個可以 `flutter run -d chrome` 開起來、但畫面仍是壽險內容的基礎專案(後續任務逐步替換內容來源與品牌)

- [ ] **Step 1:** 複製檔案
```bash
cd /Users/fortune
rsync -a --exclude='.git' --exclude='build' --exclude='.dart_tool' \
  insurance-exam-app/lib insurance-exam-app/test insurance-exam-app/web \
  insurance-exam-app/pubspec.yaml insurance-exam-app/analysis_options.yaml \
  currency-insurance-exam/
rm -rf currency-insurance-exam/assets/json
```
- [ ] **Step 2:** 改 `pubspec.yaml` 的 `name`/`description`/`version`
```yaml
name: currency_insurance_exam
description: 外幣保險資格測驗學習 APP(網頁版)
version: 0.1.0+1
```
同時把 `flutter.assets` 區塊裡的 `assets/json/` 那行移除(其餘 `assets/images/`、`assets/guides/` 保留給後續教材圖片管線)。
- [ ] **Step 3:** 改 `web/index.html` 與 `web/manifest.json` 的標題/名稱欄位為「外幣保險資格測驗」相關字樣(逐一搜尋 `保險業務員資格測驗` 字串取代)
```bash
cd /Users/fortune/currency-insurance-exam
grep -rl "保險業務員資格測驗\|insurance_exam_app" web
```
依搜尋結果逐一取代成外幣版名稱。
- [ ] **Step 4:** 驗證專案能跑
```bash
cd /Users/fortune/currency-insurance-exam
flutter pub get
flutter build web
```
Expected: build 成功無錯誤(此階段畫面內容仍是壽險殘留內容,屬預期,後續任務會替換)。
- [ ] **Step 5:** Commit
```bash
git add -A
git commit -m "Scaffold currency-insurance-exam from insurance-exam-app template"
```

---

## Task 2: Supabase schema migration

**Files:**
- Create: `supabase/migrations/0001_init_schema.sql`
- Test: `supabase/tests/0001_init_schema.test.sql`(用 `psql` 跑的斷言腳本;刻意放在 `supabase/migrations/` 之外——Supabase CLI 用檔名開頭的數字當 migration 版本號,`0001_init_schema.sql` 跟 `0001_init_schema.test.sql` 放在同一個 migrations 目錄會撞版本號,導致 `supabase db reset` 直接失敗)

**Interfaces:**
- Produces: 資料表 `course, chapters, questions, mnemonic_cards, sections, levels, level_progress, license_keys, key_sessions, key_favorites, key_wrong_answers, study_logs` + RPC `increment_key_used_count`。後續 Task 3(Dart repository)與 Task 9(seed script)依賴內容表欄位;`license_keys`/`key_sessions`/`key_favorites`/`key_wrong_answers`/`study_logs` 的表名、欄位、RPC 名稱是**逐字對照** Task 1 原樣複製過來的 `lib/core/services/lk_auth_service.dart`、`cloud_sync_service.dart`、`study_logger.dart` 這三支既有(不修改邏輯的)服務實際查詢的內容,不是自行設計——這三支檔案完全不會修改,新專案的表結構必須跟它們的查詢字串完全對上,否則登入/同步會整支壞掉。

- [ ] **Step 1:** 寫 schema SQL
```sql
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
```
- [ ] **Step 2:** 寫驗證腳本(不是空表就好,還要斷言關鍵欄位存在與 constraint 生效)
```sql
-- supabase/tests/0001_init_schema.test.sql
select 1/count(*) from information_schema.tables
  where table_name in ('course','chapters','questions','mnemonic_cards','sections',
                        'levels','level_progress','license_keys','key_sessions',
                        'key_favorites','key_wrong_answers','study_logs')
  having count(*) = 12;  -- 除以 0 會噴錯，藉此斷言剛好 12 張表都建立

-- RPC 函式也要斷言存在，這是 lk_auth_service.dart 登入流程會直接呼叫的
select 1/count(*) from pg_proc where proname = 'increment_key_used_count';

-- answer 超出範圍應被拒絕
do $$
begin
  begin
    insert into course (id, name) values (1, 'x');
    insert into chapters (id, course_id, unit_no, title) values (1,1,1,'x');
    insert into questions (id, chapter_id, question_no, question, options, answer)
      values (1,1,1,'q', array['a','b','c','d'], 9);
    raise exception 'should have failed on answer check constraint';
  exception when check_violation then
    raise notice 'PASS: answer check constraint enforced';
  end;
  rollback;
end $$;
```
- [ ] **Step 3:** 在新建的 Supabase 專案跑 migration 並執行測試
```bash
supabase link --project-ref <你的新專案 ref>
supabase db push
psql "$SUPABASE_DB_URL" -f supabase/tests/0001_init_schema.test.sql
```
Expected: 表格數斷言與 RPC 存在斷言都不噴錯(除以 0 的寫法失敗才會報錯),check constraint 測試印出 PASS。
- [ ] **Step 4:** Commit
```bash
git add supabase/migrations
git commit -m "Add Supabase schema migration for currency exam content and user data"
```

---

## Task 3: Content repository — Supabase-backed, replacing static JSON loader

**Files:**
- Modify: `lib/repositories/question_repository.dart`
- Modify: `lib/models/question.dart`(新增 `fromSupabaseRow` 具名建構子與 `keywordHint`/`plainExplanation`/`textbookPage` 欄位;既有 `fromJson`/`toJson`/欄位保留不動)
- Create: `lib/core/services/content_cache_store.dart`
- Test: `test/repositories/question_repository_test.dart`

**Interfaces:**
- Consumes: Supabase 表 `questions/chapters/mnemonic_cards/sections`(Task 2)
- Produces: `QuestionRepository` 維持原本的公開方法簽名(`getChapters()/getAllQuestions()/getAllSections()/getQuestionsByChapter()` 等),讓 Task 11–16 的 UI 元件不用重寫呼叫端

- [ ] **Step 1:** 寫失敗測試(用假的 Supabase response 驗證 repository 會呼叫正確的表並轉成 model)
```dart
// test/repositories/question_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:currency_insurance_exam/repositories/question_repository.dart';
import 'package:currency_insurance_exam/core/services/content_cache_store.dart';
import 'fakes/fake_supabase_content_source.dart';

void main() {
  test('getAllQuestions parses rows from Supabase into Question models', () async {
    final fakeSource = FakeSupabaseContentSource(questionRows: [
      {
        'id': 1, 'chapter_id': 101, 'question_no': 1, 'question': '測試題目',
        'options': ['A', 'B', 'C', 'D'], 'answer': 2, 'explanation': '解析',
        'keyword_hint': null, 'plain_explanation': null, 'textbook_page': 5,
      }
    ]);
    final repo = QuestionRepository(
      source: fakeSource,
      cache: ContentCacheStore.inMemory(),
    );

    final questions = await repo.getAllQuestions();

    expect(questions.length, 1);
    expect(questions.first.id, 1);
    expect(questions.first.answer, 2);
    expect(questions.first.options, ['A', 'B', 'C', 'D']);
  });
}
```
需要一併建立 `test/repositories/fakes/fake_supabase_content_source.dart`,實作跟真正 Supabase 呼叫同樣的介面(`Future<List<Map<String,dynamic>>> fetchQuestions()` 等),回傳建構子傳入的假資料。
- [ ] **Step 2:** 執行確認失敗(此時 `QuestionRepository` 建構子還沒有 `source`/`cache` 具名參數)
```bash
flutter test test/repositories/question_repository_test.dart
```
Expected: FAIL,錯誤訊息類似 `No named parameter with the name 'source'`。
- [ ] **Step 3a:** 擴充 `Question` model,新增 Supabase 專用的欄位與具名建構子(不動既有 `fromJson`/`toJson`)
```dart
// lib/models/question.dart（新增欄位與具名建構子，其餘不變）
class Question {
  final int id;
  final int chapterId;
  final int questionNo;
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;
  final String? keywordHint;        // 新增
  final String? plainExplanation;   // 新增
  final int? textbookPage;          // 新增

  const Question({
    required this.id,
    required this.chapterId,
    required this.questionNo,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.keywordHint,
    this.plainExplanation,
    this.textbookPage,
  });

  factory Question.fromSupabaseRow(Map<String, dynamic> row) => Question(
    id: row['id'],
    chapterId: row['chapter_id'],
    questionNo: row['question_no'],
    question: row['question'],
    options: List<String>.from(row['options']),
    answer: row['answer'],
    explanation: row['explanation'] ?? '',
    keywordHint: row['keyword_hint'],
    plainExplanation: row['plain_explanation'],
    textbookPage: row['textbook_page'],
  );

  // fromJson/toJson 保留供既有本機快取以外的用途，不刪除
}
```
- [ ] **Step 3b:** 實作 `ContentCacheStore`(本機快取,啟動時先讀快取讓畫面能立即顯示,背景再打 Supabase 更新)
```dart
// lib/core/services/content_cache_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ContentCacheStore {
  final Future<SharedPreferences>? _prefsFuture;
  final Map<String, dynamic> _memory = {};

  ContentCacheStore(this._prefsFuture);
  ContentCacheStore.inMemory() : _prefsFuture = null;

  Future<List<Map<String, dynamic>>?> read(String key) async {
    if (_prefsFuture == null) {
      final v = _memory[key];
      return v == null ? null : List<Map<String, dynamic>>.from(v);
    }
    final prefs = await _prefsFuture;
    final raw = prefs.getString('content_cache_$key');
    if (raw == null) return null;
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  Future<void> write(String key, List<Map<String, dynamic>> rows) async {
    if (_prefsFuture == null) {
      _memory[key] = rows;
      return;
    }
    final prefs = await _prefsFuture;
    await prefs.setString('content_cache_$key', jsonEncode(rows));
  }
}
```
- [ ] **Step 4:** 改 `QuestionRepository` 改吃 `source`/`cache`,並把 Supabase 呼叫抽成 `ContentSource` 介面(方便測試假注入)
```dart
// lib/repositories/question_repository.dart（節錄新增/修改部分）
abstract class ContentSource {
  Future<List<Map<String, dynamic>>> fetchQuestions();
  Future<List<Map<String, dynamic>>> fetchChapters();
  Future<List<Map<String, dynamic>>> fetchSections();
}

class SupabaseContentSource implements ContentSource {
  final _sb = Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchQuestions() async =>
      List<Map<String, dynamic>>.from(await _sb.from('questions').select());

  @override
  Future<List<Map<String, dynamic>>> fetchChapters() async =>
      List<Map<String, dynamic>>.from(await _sb.from('chapters').select());

  @override
  Future<List<Map<String, dynamic>>> fetchSections() async =>
      List<Map<String, dynamic>>.from(await _sb.from('sections').select());
}

class QuestionRepository {
  final ContentSource source;
  final ContentCacheStore cache;
  List<Chapter>? _chapters;
  List<Question>? _questions;
  List<Section>? _sections;

  QuestionRepository({ContentSource? source, ContentCacheStore? cache})
      : source = source ?? SupabaseContentSource(),
        cache = cache ?? ContentCacheStore(SharedPreferences.getInstance());

  Future<List<Question>> getAllQuestions() async {
    if (_questions != null) return _questions!;
    var rows = await cache.read('questions');
    rows ??= await source.fetchQuestions();
    unawaited(_refreshQuestionsInBackground());
    _questions = rows.map((r) => Question.fromSupabaseRow(r)).toList();
    return _questions!;
  }

  Future<void> _refreshQuestionsInBackground() async {
    try {
      final fresh = await source.fetchQuestions();
      await cache.write('questions', fresh);
      _questions = fresh.map((r) => Question.fromSupabaseRow(r)).toList();
    } catch (_) {
      // 背景刷新失敗不影響已顯示的內容
    }
  }

  Future<List<Chapter>> getChapters() async {
    if (_chapters != null) return _chapters!;
    var rows = await cache.read('chapters');
    rows ??= await source.fetchChapters();
    unawaited(_refreshChaptersInBackground());
    _chapters = rows.map((r) => Chapter.fromSupabaseRow(r)).toList();
    return _chapters!;
  }

  Future<void> _refreshChaptersInBackground() async {
    try {
      final fresh = await source.fetchChapters();
      await cache.write('chapters', fresh);
      _chapters = fresh.map((r) => Chapter.fromSupabaseRow(r)).toList();
    } catch (_) {
      // 背景刷新失敗不影響已顯示的內容
    }
  }

  Future<List<Section>> getAllSections() async {
    if (_sections != null) return _sections!;
    var rows = await cache.read('sections');
    rows ??= await source.fetchSections();
    unawaited(_refreshSectionsInBackground());
    _sections = rows.map((r) => Section.fromSupabaseRow(r)).toList();
    return _sections!;
  }

  Future<void> _refreshSectionsInBackground() async {
    try {
      final fresh = await source.fetchSections();
      await cache.write('sections', fresh);
      _sections = fresh.map((r) => Section.fromSupabaseRow(r)).toList();
    } catch (_) {
      // 背景刷新失敗不影響已顯示的內容
    }
  }

  Future<List<Section>> getSectionsByChapter(int chapterId) async {
    final all = await getAllSections();
    final result = all.where((s) => s.chapterId == chapterId).toList();
    result.sort((a, b) => a.order.compareTo(b.order));
    return result;
  }

  Future<List<Question>> getQuestionsByChapter(int chapterId) async {
    final all = await getAllQuestions();
    return all.where((q) => q.chapterId == chapterId).toList();
  }

  Future<List<Question>> getQuestionsByIds(List<int> ids) async {
    final all = await getAllQuestions();
    final idSet = ids.toSet();
    return all.where((q) => idSet.contains(q.id)).toList();
  }
}
```
`Chapter`(`lib/models/chapter.dart`)與 `Section`(`lib/models/section.dart`)都比照 Task 3 Step 3a 對 `Question` 做的事:各自新增一個 `fromSupabaseRow` 具名建構子讀 snake_case 欄位——`chapter.dart` 讀 `course_id`→`courseId`、`unit_no`→`unitNo`、`weight`→`weight`(欄位名稱不變,沿用既有 model,不新增 `order` 欄位);`section.dart` 讀 `chapter_id`→`chapterId`、`order`→`order`。既有 `fromJson`/`toJson`/欄位不動。`getRandomQuestions`/`getRandomQuestionsByCourse` 兩個既有方法內部只呼叫 `getAllQuestions()` 取資料後在記憶體內篩選/洗牌,不直接碰 `source`/`cache`,原始實作不需要修改。
- [ ] **Step 5:** 執行確認通過
```bash
flutter test test/repositories/question_repository_test.dart
```
Expected: PASS。
- [ ] **Step 6:** Commit
```bash
git add lib/repositories/question_repository.dart lib/models/question.dart lib/core/services/content_cache_store.dart test/repositories
git commit -m "Switch question content source from bundled JSON to Supabase with local cache"
```

---

## Task 4: Deterministic PDF question-bank segmentation

**Revision note (superseding an earlier version of this task):** the first
implementation of this task used `pdftotext -layout` plus a line-marker regex
to segment questions. Task 6's review caught it producing badly corrupted
question/option text for the majority of the 306 real questions — `pdftotext
-layout` flattens the PDF's actual two-column table (問題/選項 一欄,
解析/頁碼 另一欄) into single lines by row position, which interleaves the
two columns' text whenever one cell wraps to more lines than the other,
silently truncating options and contaminating explanations with the next
question's stem. Investigation (see ledger) found the source PDF has a real,
detectable table grid that `pdfplumber`'s `page.extract_tables()` reads
directly, giving clean, already-column-separated data with **zero** bad rows
verified across all 306 real questions — eliminating the corruption at its
root instead of patching around it. This revision replaces the whole
approach; Task 5 and Task 6 below are updated to match the new output shape.

**Files:**
- Create: `scripts/extract/segment_questions.py`
- Test: `scripts/extract/test_segment_questions.py`

**Interfaces:**
- Consumes: `/Users/fortune/Documents/外幣/外幣題庫_ABECD卷整理(含新增)V1.pdf`(唯讀,不修改原始檔案)
- Produces: `scripts/extract/output/raw_blocks.json` — 一個 list,每筆
  `{exam_set, question_no, answer, question_raw, explanation_raw}`。
  `question_raw`/`explanation_raw` 直接來自 PDF 表格的第 3、4 欄,已經是
  乾淨、正確斷行合併過的文字,不會有欄位互相污染的問題——這是用
  `pdfplumber` 讀取 PDF 本身真實存在的表格格線做到的,不是用視覺位置去猜。
  供 Task 5、6 進一步處理。

- [ ] **Step 1:** 寫失敗測試(直接用 pdfplumber 表格抽取後會拿到的那種已結構化 row 當 fixture,不需要真的開 PDF)
```python
# scripts/extract/test_segment_questions.py
from segment_questions import parse_table_row, detect_exam_set

def test_parses_valid_question_row():
    row = ["10", "4",
           "「投資型保險投資管理辦法」第12條規定...不得有下列哪些情事：\n1)AB 2)ABCD 3)A 4)ABC",
           "參閱課本第32頁\n【解析】D選項錯在\"要保人\"，應為\"保險人\""]
    block = parse_table_row(row, current_exam_set="A")
    assert block["exam_set"] == "A"
    assert block["question_no"] == 10
    assert block["answer"] == 4
    assert "不得有下列哪些情事" in block["question_raw"]
    assert "【解析】" in block["explanation_raw"]

def test_returns_none_for_header_row():
    row = ["題號", "答案", "A卷", "答案說明"]
    assert parse_table_row(row, current_exam_set="A") is None

def test_returns_none_for_malformed_row():
    assert parse_table_row(["1", None, "text", "exp"], current_exam_set="A") is None
    assert parse_table_row(["not-a-number", "4", "text", "exp"], current_exam_set="A") is None

def test_detects_exam_set_label_from_header():
    assert detect_exam_set(["題號", "答案", "A卷", "答案說明"]) == "A"
    assert detect_exam_set(["題號", "答案", "新增", "答案說明"]) == "新增"
    assert detect_exam_set(["10", "4", "some question", "some explanation"]) is None
```
- [ ] **Step 2:** 執行確認失敗
```bash
cd scripts/extract && python3 -m pytest test_segment_questions.py -v
```
Expected: FAIL(`ModuleNotFoundError: No module named 'segment_questions'`)。
- [ ] **Step 3:** 實作(純函式,只負責把 pdfplumber 表格抽取後的一個 row 轉成結構化 block,不在這裡碰 PDF 檔案本身)
```python
# scripts/extract/segment_questions.py
import re

EXAM_LABEL = re.compile(r'^(A卷|B卷|C卷|D卷|E卷|新增)$')

def detect_exam_set(header_row):
    for cell in header_row:
        if cell:
            m = EXAM_LABEL.match(cell.strip())
            if m:
                return m.group(1).replace('卷', '')
    return None

def parse_table_row(row, current_exam_set):
    if len(row) != 4:
        return None
    qno, ans, qtext, exp = row
    if qno is None or ans is None or qtext is None:
        return None
    try:
        qno_i = int(qno.strip())
        ans_i = int(ans.strip())
    except (ValueError, AttributeError):
        return None
    return {
        "exam_set": current_exam_set,
        "question_no": qno_i,
        "answer": ans_i,
        "question_raw": qtext,
        "explanation_raw": exp or "",
    }
```
- [ ] **Step 4:** 執行確認通過
```bash
python3 -m pytest test_segment_questions.py -v
```
Expected: PASS。
- [ ] **Step 5:** 對真實 PDF 全文跑一次,並用「總筆數落在合理範圍、每個 exam_set 都有資料、沒有無法解析的 row」做整體驗收(不是單元測試,是資料驗收腳本)
```python
# scripts/extract/run_segmentation.py
import json
import pdfplumber
from pathlib import Path
from segment_questions import parse_table_row, detect_exam_set

PDF = Path.home() / "Documents/外幣/外幣題庫_ABECD卷整理(含新增)V1.pdf"
OUT = Path(__file__).parent / "output/raw_blocks.json"

def extract_all_blocks():
    all_blocks = []
    current_set = None
    with pdfplumber.open(str(PDF)) as pdf:
        for page in pdf.pages:
            for table in page.extract_tables():
                if not table:
                    continue
                detected = detect_exam_set(table[0])
                if detected:
                    current_set = detected
                for row in table[1:]:
                    block = parse_table_row(row, current_set)
                    if block:
                        all_blocks.append(block)
    return all_blocks

if __name__ == "__main__":
    all_blocks = extract_all_blocks()
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(all_blocks, ensure_ascii=False, indent=2))
    print(f"{len(all_blocks)} blocks written to {OUT}")
    assert 200 <= len(all_blocks) <= 320, f"unexpected block count: {len(all_blocks)}"
    sets_present = {b["exam_set"] for b in all_blocks}
    assert {"A", "B", "C", "D", "E", "新增"}.issubset(sets_present), sets_present
```
Run: `python3 run_segmentation.py`
Expected: 印出總筆數(已知真實值為 306,A/B/C/D/E 各 50 筆、新增 56 筆)。這次驗收除了總數與卷別齊全,**還要額外抽查至少 10-15 筆真實輸出**,確認 `question_raw` 包含完整 4 個選項(不是被截斷)、`explanation_raw` 是乾淨的解析文字(不包含下一題的題幹或被截斷的選項文字)——這正是舊做法(`pdftotext -layout`)壞掉的地方,新做法理論上不會有這問題,但既然是關乎真實學員要看到的考題內容,必須實際驗證,不能只看總數字對不對。
- [ ] **Step 6:** Commit
```bash
git add scripts/extract/segment_questions.py scripts/extract/test_segment_questions.py scripts/extract/run_segmentation.py
git commit -m "Add deterministic PDF question-bank segmentation via pdfplumber table extraction"
```

---

## Task 5: Extract verified original mnemonic phrases (口訣)

**Revision note:** updated to consume `explanation_raw` (Task 4's new,
already-column-separated output) instead of a single mixed `raw_text` blob.
口訣 only ever appears in the 解析 column, so this narrows the search surface
and removes any risk of accidentally matching something in the question/option
text — a strict improvement, no functional loss.

**Files:**
- Create: `scripts/extract/extract_mnemonics.py`
- Test: `scripts/extract/test_extract_mnemonics.py`

**Interfaces:**
- Consumes: `scripts/extract/output/raw_blocks.json`(Task 4,讀 `explanation_raw` 欄位)
- Produces: `scripts/extract/output/mnemonic_cards_original.json`,每筆 `{phrase, meaning_raw, related_question_nos}`(`related_question_nos` 是 `[{exam_set, question_no}, ...]` 的清單——同一句口訣常常在 A/B/C/D/E 幾份考卷裡重複出現於相似題目,萃取時要依 `phrase` 去重合併,不要每個出現位置各自產生一筆獨立紀錄,否則後面 Task 9 匯入會出現好幾張內容一樣的口訣卡)。這個檔案不進 git(產出的資料檔,Step 6 的 commit 範圍只有 3 支程式碼檔案)。`source` 由 Task 9 匯入時固定寫 `"original"`,不需要這個檔案自己存。

- [ ] **Step 1:** 寫失敗測試,用本次對話已經人工核對過的兩個真實案例當 fixture(金三角、構政制),fixture 直接是解析欄位的文字(不再夾雜題目/選項)
```python
# scripts/extract/test_extract_mnemonics.py
from extract_mnemonics import extract_mnemonic_from_block

def test_extracts_explicit_koujue_marker():
    explanation_raw = "參閱課本第84頁\n【解析】外匯存款→口訣 存放『金三角』→資金百分之三。"
    result = extract_mnemonic_from_block(explanation_raw)
    assert result is not None
    assert result["phrase"] == "金三角"

def test_extracts_koujue_without_quote_marks():
    explanation_raw = "參閱課本第113頁\n【解析】國外投資風險監控管理措施→口訣構政制"
    result = extract_mnemonic_from_block(explanation_raw)
    assert result is not None
    assert result["phrase"] == "構政制"

def test_returns_none_when_no_mnemonic_present():
    explanation_raw = "參閱課本第10頁\n【解析】依保險法第146條規定，答案為第2項。"
    assert extract_mnemonic_from_block(explanation_raw) is None
```
- [ ] **Step 2:** 確認失敗
```bash
python3 -m pytest test_extract_mnemonics.py -v
```
Expected: FAIL(`ModuleNotFoundError`)。
- [ ] **Step 3:** 實作(兩種樣式都要接:`口訣『X』` 明確引號樣式,以及 `標題→X`、`X→Y制` 這種緊接在「口訣」字樣後、以頓號/箭頭分隔到句尾或下個標點的樣式)。`_QUOTED` 的擷取長度要有上限,避免把整段解析文字都吃進去。
```python
# scripts/extract/extract_mnemonics.py
import re

_QUOTED = re.compile(r'口訣[^『\n]{0,10}『([^』\n]{1,20})』')
_BARE = re.compile(r'口訣\s*[→]?\s*([^\s。\n]{2,8})')

def extract_mnemonic_from_block(explanation_raw: str):
    if "口訣" not in explanation_raw:
        return None
    m = _QUOTED.search(explanation_raw)
    if m:
        return {"phrase": m.group(1), "meaning_raw": explanation_raw.strip()}
    m = _BARE.search(explanation_raw)
    if m:
        return {"phrase": m.group(1), "meaning_raw": explanation_raw.strip()}
    return None
```
- [ ] **Step 4:** 確認通過
```bash
python3 -m pytest test_extract_mnemonics.py -v
```
Expected: PASS。
- [ ] **Step 5:** 對 `raw_blocks.json` 全量跑,依 `phrase` 去重合併後輸出結果,並列印出每一筆讓你人工過目(這批因為是「原文萃取」,人工過目是核對有沒有截斷/誤判,不是覆核法規正確性)
```python
# scripts/extract/run_extract_mnemonics.py
import json
from pathlib import Path
from extract_mnemonics import extract_mnemonic_from_block

BLOCKS = json.loads((Path(__file__).parent / "output/raw_blocks.json").read_text())
grouped = {}
for b in BLOCKS:
    r = extract_mnemonic_from_block(b["explanation_raw"])
    if not r:
        continue
    entry = grouped.setdefault(r["phrase"], {
        "phrase": r["phrase"], "meaning_raw": r["meaning_raw"], "related_question_nos": [],
    })
    entry["related_question_nos"].append({"exam_set": b["exam_set"], "question_no": b["question_no"]})

results = list(grouped.values())
out = Path(__file__).parent / "output/mnemonic_cards_original.json"
out.write_text(json.dumps(results, ensure_ascii=False, indent=2))
print(f"{len(results)} unique original mnemonic phrases found:")
for r in results:
    refs = ", ".join(f"{q['exam_set']}-{q['question_no']}" for q in r["related_question_nos"])
    print(f"  {r['phrase']}  (from: {refs})")
```
Run: `python3 run_extract_mnemonics.py`,把印出的清單貼給我人工過目確認(這步驟等你跑完實際執行時提交結果給我檢視,不是自動放行)。
- [ ] **Step 6:** Commit
```bash
git add scripts/extract/extract_mnemonics.py scripts/extract/test_extract_mnemonics.py scripts/extract/run_extract_mnemonics.py
git commit -m "Extract verified original mnemonic phrases from question bank explanations"
```

---

## Task 6: Structure raw blocks into question records (options/answer/explanation split)

**Revision note:** Task 4's new output already separates `question_raw` from
`explanation_raw` at the source (via the PDF's real table columns), so this
task no longer needs to locate a `【解析】` marker inside a single mixed
blob to split question from explanation — that was the single biggest
source of corruption in the original approach (a marker landing mid-wrap
would silently truncate options and leak explanation text into the next
question, and vice versa). This task now only needs to: (a) split
`question_raw`'s trailing `1)...2)...3)...4)...` into stem + options, and
(b) pull the page number out of `explanation_raw`, keeping the rest as
`explanation`.

**Files:**
- Create: `scripts/extract/structure_questions.py`
- Test: `scripts/extract/test_structure_questions.py`

**Interfaces:**
- Consumes: `scripts/extract/output/raw_blocks.json`(讀 `question_raw`/`explanation_raw`)
- Produces: `scripts/extract/output/questions_structured.json`,每筆含 `question, options[], explanation, textbook_page`(此步驟先不填 `chapter_id`,由 Task 7 補上)

- [ ] **Step 1:** 寫失敗測試,涵蓋兩種常見格式:一般四選一,以及題幹夾帶英文字母子選項、答案為組合(如 "1)BCD") 的格式
```python
# scripts/extract/test_structure_questions.py
from structure_questions import structure_block

def test_simple_four_choice():
    question_raw = "付之款項向______辦理結匯，並應將結匯明細資料留存以供查核。\n1)銀行業 2)中央銀行\n3)財政部 4)金管會"
    explanation_raw = "參閱課本第23頁\n【解析】結匯→向銀行業辦理"
    result = structure_block(question_raw, explanation_raw)
    assert result["textbook_page"] == 23
    assert result["explanation"] == "結匯→向銀行業辦理"
    assert len(result["options"]) == 4
    assert result["options"][0] == "銀行業"

def test_lettered_combination_choice():
    question_raw = "依「保險業辦理外匯業務管理辦法」規定，保險業得申請辦理下列哪些外匯業務：A以外幣收付\n之人身保險業務B以外幣收付之非投資型年金保險\n1) A B C 2) A C 3) B D 4) C D"
    explanation_raw = "參閱課本第20頁\n【解析】B外投年轉臺 D外幣放款"
    result = structure_block(question_raw, explanation_raw)
    assert result["options"] == ["A B C", "A C", "B D", "C D"]
    assert "外投年轉臺" in result["explanation"]
```
- [ ] **Step 2:** 確認失敗
```bash
python3 -m pytest test_structure_questions.py -v
```
Expected: FAIL(`ModuleNotFoundError`)。
- [ ] **Step 3:** 實作(`question_raw` 用「數字)」切出選項,`explanation_raw` 用「參閱課本第N頁」正則抓頁碼、其餘接在後面當解析)
```python
# scripts/extract/structure_questions.py
import re

_PAGE = re.compile(r'參閱課本第\s*(\d+)')
_EXPLANATION = re.compile(r'【解析】(.*)', re.S)
_OPTION_SPLIT = re.compile(r'\d\)\s*')

def structure_block(question_raw: str, explanation_raw: str):
    q_text = " ".join(question_raw.split("\n")).strip()
    exp_text = " ".join(explanation_raw.split("\n")).strip()

    page_match = _PAGE.search(exp_text)
    textbook_page = int(page_match.group(1)) if page_match else None

    exp_match = _EXPLANATION.search(exp_text)
    explanation = exp_match.group(1).strip() if exp_match else _PAGE.sub("", exp_text).strip()

    # 選項一律以 "數字)" 切，第一段(切割前的文字)是題幹
    parts = _OPTION_SPLIT.split(q_text)
    question = parts[0].strip()
    options = [p.strip() for p in parts[1:] if p.strip()]

    return {
        "question": question,
        "options": options,
        "explanation": explanation,
        "textbook_page": textbook_page,
    }
```
- [ ] **Step 4:** 確認通過
```bash
python3 -m pytest test_structure_questions.py -v
```
Expected: PASS。
- [ ] **Step 5:** 對全量 `raw_blocks.json` 跑,並輸出「無法正確切出 4 個選項」的筆數與內容清單(這些屬於格式特例,需要人工個別檢視,不能默默丟掉)。因為 Task 4 已經改用乾淨的表格抽取,這裡預期絕大多數題目都能正確切出 4 個選項——如果 needs_review 比例仍然偏高(例如超過 15-20%),要實際打開幾筆看內容,判斷是 `structure_block` 本身的切分邏輯還不夠(例如某些題目選項本身就不是用「數字)」格式寫的),而不是想都不想就當作預期中的雜訊。
```python
# scripts/extract/run_structure_questions.py
import json
from pathlib import Path
from structure_questions import structure_block

BLOCKS = json.loads((Path(__file__).parent / "output/raw_blocks.json").read_text())
structured, needs_review = [], []
for b in BLOCKS:
    s = structure_block(b["question_raw"], b["explanation_raw"])
    s.update({"exam_set": b["exam_set"], "question_no": b["question_no"], "answer": b["answer"]})
    if len(s["options"]) != 4:
        needs_review.append(s)
    else:
        structured.append(s)

Path(__file__).parent.joinpath("output/questions_structured.json").write_text(
    json.dumps(structured, ensure_ascii=False, indent=2))
Path(__file__).parent.joinpath("output/questions_needs_review.json").write_text(
    json.dumps(needs_review, ensure_ascii=False, indent=2))

print(f"structured cleanly: {len(structured)}")
print(f"needs manual review (options != 4): {len(needs_review)}")
```
Run: `python3 run_structure_questions.py`。把 `questions_needs_review.json` 的內容整批交給我人工確認怎麼處理(通常是 PDF 斷行造成選項黏在一起,少量手動修正即可,不要自動猜測答案內容)。**另外對「structured cleanly」那批也要抽查 10-15 筆**,確認選項真的完整、沒有被截斷或夾雜下一題內容——不能只看 `len(options)==4` 這個數字條件就直接信任內容是對的。
- [ ] **Step 6:** Commit
```bash
git add scripts/extract/structure_questions.py scripts/extract/test_structure_questions.py scripts/extract/run_structure_questions.py
git commit -m "Structure raw question blocks into question/options/explanation/textbook_page records"
```

---

## Task 7: Chapter classification via regulation-name content matching

**Revision note (supersedes an earlier page-range-based version of this
task):** the first implementation built `chapter_page_ranges.json` correctly
(verified by direct page-by-page reading of the real 263-page slide deck —
keep this file, it's still needed by Task 16's guide-image viewer, which
maps slide-deck PAGES to chapters, an entirely separate concern from
classifying QUESTIONS). But when used to classify questions via their
`textbook_page` field, a rigorous cross-check (matching literal regulation
names quoted in question text against the assigned chapter) found **0/84
(100%) mismatch** — the question bank's own `參閱課本第N頁` page citations
turn out not to reliably correspond to real page positions in the deck at
all (verified: the same regulation article, cited by different exam-set
variants of a near-duplicate question, pointed at two different pages, only
one of which was correct — i.e. citation drift in the *source material*
itself, not an extraction bug). Page-based classification of questions is
therefore abandoned. This revision classifies each question by matching its
own text against each chapter's regulation name directly — the same
approach that correctly resolved all 84 cross-check cases with zero
reliance on the unreliable page field.

**Files:**
- Create: `scripts/extract/chapter_page_ranges.json`(手動盤點,非程式產生——仍然需要,供 Task 16 的教材頁碼對照使用,跟這裡的題目分類已經無關)
- Create: `scripts/extract/classify_chapters.py`
- Test: `scripts/extract/test_classify_chapters.py`

**Interfaces:**
- Consumes: `scripts/extract/output/questions_structured.json`(Task 6,讀 `question`/`explanation`,不再讀 `textbook_page`)
- Produces: `scripts/extract/output/questions_with_chapter.json`(補上 `chapter_id`)

- [ ] **Step 1:** 承襲前一版已經人工核對過、逐頁讀過真實投影片確認的 `chapter_page_ranges.json`(不用重做,若檔案已存在直接沿用):
```json
[
  {"chapter_id": 1, "title": "外幣保險開放紀事", "page_start": 1, "page_end": 15},
  {"chapter_id": 3, "title": "人身保險業辦理以外幣收付之非投資型人身保險業務應具備資格條件及注意事項", "page_start": 16, "page_end": 27},
  {"chapter_id": 2, "title": "保險業辦理外匯業務管理辦法", "page_start": 28, "page_end": 50},
  {"chapter_id": 6, "title": "投資型保險投資管理辦法", "page_start": 51, "page_end": 95},
  {"chapter_id": 4, "title": "管理外匯條例", "page_start": 96, "page_end": 118},
  {"chapter_id": 5, "title": "外匯收支或交易申報辦法", "page_start": 119, "page_end": 143},
  {"chapter_id": 7, "title": "保險業辦理國外投資管理辦法", "page_start": 144, "page_end": 192},
  {"chapter_id": 8, "title": "人身保險基本概念及其他", "page_start": 193, "page_end": 263}
]
```
- [ ] **Step 2:** 寫失敗測試,涵蓋:題目本文直接引用法規名稱可以分類、沒有引用任何已知法規名稱回傳 None、同一題同時出現兩個不同法規名稱時以先出現者為準
```python
# scripts/extract/test_classify_chapters.py
from classify_chapters import classify_by_content

def test_classifies_by_regulation_name_in_question():
    q = "依「投資型保險投資管理辦法」第12條規定，保險人行使投資型保險專設帳簿持有股票之投票表決權者..."
    assert classify_by_content(q, "") == 6

def test_classifies_by_regulation_name_in_explanation():
    assert classify_by_content("下列何者正確？", "依「管理外匯條例」第4條規定，答案為第2項") == 4

def test_returns_none_when_no_known_regulation_named():
    assert classify_by_content("下列何者為外幣保險開放的正確歷程？", "詳見課程說明") is None

def test_first_mentioned_regulation_wins_when_both_present():
    q = "「保險業辦理外匯業務管理辦法」與「管理外匯條例」的關係為何？"
    assert classify_by_content(q, "") == 2
```
- [ ] **Step 3:** 確認失敗 → 實作(用每章唯一、可辨識的法規全名或關鍵子字串當比對樣式;第 1、8 章沒有單一法規名稱可比對,本來就分類不到,交給人工歸類)
```python
# scripts/extract/classify_chapters.py
import re

# 依第一次出現的位置比對，所以放進 list 而非 dict（dict 在部分 Python 版本
# 不保證插入順序在比對時被尊重；用 list 明確保證「先出現的法規優先」）
_REGULATION_PATTERNS = [
    (2, re.compile(r'保險業辦理外匯業務管理辦法')),
    (3, re.compile(r'非投資型人身保險業務應具備資格條件及注意事項')),
    (4, re.compile(r'管理外匯條例')),
    (5, re.compile(r'外匯收支或交易申報辦法')),
    (6, re.compile(r'投資型保險投資管理辦法')),
    (7, re.compile(r'保險業辦理國外投資管理辦法')),
]

def classify_by_content(question: str, explanation: str):
    combined = f"{question} {explanation}"
    best_id, best_pos = None, None
    for chapter_id, pattern in _REGULATION_PATTERNS:
        m = pattern.search(combined)
        if m and (best_pos is None or m.start() < best_pos):
            best_id, best_pos = chapter_id, m.start()
    return best_id
```
- [ ] **Step 4:** 確認通過
```bash
python3 -m pytest test_classify_chapters.py -v
```
Expected: 4 個測試全部 PASS。
- [ ] **Step 5:** 全量套用,並印出「無法分類(題目與解析都沒有點名任何一個法規)」的題目清單供人工抽查。**這一步預期會有相當比例分類不到**(第1、8章本來就沒有單一法規名稱可比對,加上部分題目泛泛而論、沒有直接點名法規),這是預期中的行為,不是程式錯誤——把清單交給我人工歸類,不要為了衝高分類率硬湊關鍵字規則。
```python
# scripts/extract/run_classify_chapters.py
import json
from pathlib import Path
from classify_chapters import classify_by_content

QUESTIONS = json.loads((Path(__file__).parent / "output/questions_structured.json").read_text())

classified, unclassified = [], []
for q in QUESTIONS:
    cid = classify_by_content(q["question"], q["explanation"])
    if cid is None:
        unclassified.append(q)
    else:
        q["chapter_id"] = cid
        classified.append(q)

Path(__file__).parent.joinpath("output/questions_with_chapter.json").write_text(
    json.dumps(classified, ensure_ascii=False, indent=2))
print(f"classified: {len(classified)}, unclassified: {len(unclassified)}")
for q in unclassified[:20]:
    print(f"  [{q['exam_set']}-{q['question_no']}] {q['question'][:40]}")
```
Run 完之後,**對分類到的結果也要抽查 15-20 筆**(不只是印出未分類清單而已),實際讀題目內容確認分到的章節在主題上真的說得通,避免同一句話同時提到兩個法規、或法規名稱只是題目裡順帶提及但實際考點是別的規定這類誤判。把 unclassified 清單和抽查結果一起交給我人工確認。
- [ ] **Step 6:** Commit
```bash
git add scripts/extract/chapter_page_ranges.json scripts/extract/classify_chapters.py scripts/extract/test_classify_chapters.py scripts/extract/run_classify_chapters.py
git commit -m "Classify questions into the 8 major chapters via regulation-name content matching"
```

---

## Task 8: keyword_hint derivation from existing explanations

**Files:**
- Create: `scripts/extract/derive_keyword_hint.py`
- Test: `scripts/extract/test_derive_keyword_hint.py`

**Interfaces:**
- Consumes: `explanation` 欄位(Task 6/7 輸出)
- Produces: 幫每筆問題補上 `keyword_hint` 欄位到 `output/questions_with_chapter.json`

- [ ] **Step 1:** 寫失敗測試(用已核對過的真實解析文字驗證擷取邏輯)
```python
# scripts/extract/test_derive_keyword_hint.py
from derive_keyword_hint import derive_keyword_hint

def test_extracts_arrow_segment():
    assert derive_keyword_hint("結匯→向銀行業辦理") == "結匯→向銀行業辦理"

def test_falls_back_to_truncated_explanation_when_no_arrow():
    text = "依保險法第146條規定，本題答案為第2項，因為該項符合國外投資範圍之定義"
    hint = derive_keyword_hint(text)
    assert len(hint) <= 40
    assert hint.startswith("依保險法第146條規定")
```
- [ ] **Step 2:** 確認失敗 → 實作 → 確認通過
```python
# scripts/extract/derive_keyword_hint.py
def derive_keyword_hint(explanation: str, max_len: int = 40) -> str:
    if "→" in explanation:
        # 取含箭頭的那一段（通常就是最精簡的破題句）
        segment = next(s for s in explanation.split("。") if "→" in s)
        return segment.strip()
    return explanation[:max_len]
```
```bash
python3 -m pytest test_derive_keyword_hint.py -v
```
Expected: PASS。
- [ ] **Step 3:** 全量套用並附加到既有結構化 JSON
```python
# scripts/extract/run_derive_keyword_hint.py
import json
from pathlib import Path
from derive_keyword_hint import derive_keyword_hint

PATH = Path(__file__).parent / "output/questions_with_chapter.json"
questions = json.loads(PATH.read_text())
for q in questions:
    q["keyword_hint"] = derive_keyword_hint(q["explanation"])
PATH.write_text(json.dumps(questions, ensure_ascii=False, indent=2))
print(f"keyword_hint 已補上 {len(questions)} 筆")
```
- [ ] **Step 4:** Commit
```bash
git add scripts/extract/derive_keyword_hint.py scripts/extract/test_derive_keyword_hint.py scripts/extract/run_derive_keyword_hint.py
git commit -m "Derive keyword_hint from existing explanation text"
```

---

## Task 9: Seed Supabase — questions, chapters, mnemonic_cards, course

**Files:**
- Create: `scripts/seed/seed_content.py`
- Test: `scripts/seed/test_seed_content.py`(針對 payload 組裝邏輯的單元測試,不連真的資料庫)

**Interfaces:**
- Consumes: `scripts/extract/output/questions_with_chapter.json`、`scripts/extract/output/mnemonic_cards_original.json`、`chapter_page_ranges.json`(Task 4–8 產出)
- Produces: Supabase 表 `course/chapters/questions/mnemonic_cards` 有資料;供 Task 3 的 repository 與後續 UI 任務讀取。另外寫出 `scripts/extract/output/questions_seeded.json`(每筆問題多一個 `id` 欄位,值等於這次實際寫進 Supabase `questions.id` 的值)——Task 12 的 18 關切分依賴這個檔案取得跟 Supabase 一致的 question id,不能自己重新推算

- [ ] **Step 1:** 寫失敗測試(驗證 JSON → Supabase row payload 的欄位轉換,不驗證網路呼叫)
```python
# scripts/seed/test_seed_content.py
from seed_content import to_question_row

def test_converts_structured_question_to_supabase_row():
    q = {
        "chapter_id": 2, "question_no": 5, "question": "測試題",
        "options": ["A", "B", "C", "D"], "answer": 1,
        "explanation": "解析", "keyword_hint": "提示", "textbook_page": 23,
        "exam_set": "A",
    }
    row = to_question_row(q, id_=1)
    assert row["id"] == 1
    assert row["chapter_id"] == 2
    assert row["options"] == ["A", "B", "C", "D"]
    assert row["exam_set"] == "A"
```
- [ ] **Step 2:** 確認失敗 → 實作
```python
# scripts/seed/seed_content.py
import json, os, uuid
from pathlib import Path
from supabase import create_client

# 固定命名空間，讓同一句 phrase 每次重跑都算出同一個 uuid——mnemonic_cards.id
# 預設是 uuid_generate_v4()（隨機），upsert 若不帶 id 就永遠對不上衝突目標，
# 每次重跑都會變成新增而不是更新，整張表會一直長。
_MNEMONIC_ID_NAMESPACE = uuid.UUID("6f2f9a1e-8f2b-4c1e-9c3a-2b7e6d1f4a90")

def _mnemonic_id(phrase: str) -> str:
    return str(uuid.uuid5(_MNEMONIC_ID_NAMESPACE, phrase))

def to_question_row(q: dict, id_: int) -> dict:
    return {
        "id": id_,
        "chapter_id": q["chapter_id"],
        "question_no": q["question_no"],
        "question": q["question"],
        "options": q["options"],
        "answer": q["answer"],
        "explanation": q["explanation"],
        "keyword_hint": q.get("keyword_hint"),
        "textbook_page": q.get("textbook_page"),
        "exam_set": q.get("exam_set"),
    }

def seed():
    sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"])
    ranges = json.loads((Path(__file__).parent.parent / "extract/chapter_page_ranges.json").read_text())
    sb.table("course").upsert({"id": 1, "name": "外幣保險資格測驗認證班"}).execute()
    sb.table("chapters").upsert([
        {"id": r["chapter_id"], "course_id": 1, "unit_no": r["chapter_id"], "title": r["title"], "weight": ""}
        for r in ranges
    ]).execute()

    questions = json.loads((Path(__file__).parent.parent / "extract/output/questions_with_chapter.json").read_text())
    rows = [to_question_row(q, i + 1) for i, q in enumerate(questions)]
    sb.table("questions").upsert(rows).execute()

    # 把這次實際指派的 id 寫回一個新檔案，Task 12 (18關切分) 依賴這個檔案取得
    # 跟 Supabase 裡完全一致的 question id，不能靠「兩支腳本各自重算 enumerate+1」
    # 這種隱性假設互相對齊 —— 那樣只要任一邊改了篩選/排序條件就會悄悄兜不起來。
    seeded = [{**q, "id": rows[i]["id"]} for i, q in enumerate(questions)]
    (Path(__file__).parent.parent / "extract/output/questions_seeded.json").write_text(
        json.dumps(seeded, ensure_ascii=False, indent=2))

    # (exam_set, question_no) -> (question db id, chapter_id)，供口訣卡與原題目正確掛勾
    lookup = {
        (q["exam_set"], q["question_no"]): (rows[i]["id"], rows[i]["chapter_id"])
        for i, q in enumerate(questions)
    }

    mnemonics = json.loads((Path(__file__).parent.parent / "extract/output/mnemonic_cards_original.json").read_text())
    mnemonic_rows, skipped = [], []
    for m in mnemonics:
        # related_question_nos 是一個 [{exam_set, question_no}, ...] 清單（同一句口訣
        # 常出現在多份考卷的相似題目，Task 5 已依 phrase 去重合併），這裡把每一個都
        # 對應回真正的 question id，缺一筆不代表整張口訣卡作廢，只跳過那一筆關聯。
        related_ids, chapter_id = [], None
        for ref in m["related_question_nos"]:
            key = (ref["exam_set"], ref["question_no"])
            if key not in lookup:
                skipped.append({**ref, "phrase": m["phrase"]})
                continue
            q_id, cid = lookup[key]
            related_ids.append(q_id)
            chapter_id = chapter_id or cid  # 用第一個對得上的題目所屬章節代表整張卡
        if not related_ids:
            continue  # 這句口訣的所有出處都對應不到已分類的題目，整張卡跳過
        mnemonic_rows.append({
            "id": _mnemonic_id(m["phrase"]),
            "chapter_id": chapter_id,
            "phrase": m["phrase"], "meaning": [m["meaning_raw"]],
            "source": "original", "approved": True,
            "related_question_ids": related_ids,
        })
    if mnemonic_rows:
        sb.table("mnemonic_cards").upsert(mnemonic_rows).execute()
    if skipped:
        print(f"警告：{len(skipped)} 筆口訣卡的出處題目對應不到已分類的題目，需人工確認：")
        for s in skipped:
            print(f"  [{s['exam_set']}-{s['question_no']}] {s['phrase']}")
    return len(rows), len(mnemonic_rows)

if __name__ == "__main__":
    n_q, n_m = seed()
    print(f"seeded {n_q} questions, {n_m} mnemonic cards")
```
- [ ] **Step 3:** 確認測試通過
```bash
python3 -m pytest scripts/seed/test_seed_content.py -v
```
Expected: PASS。
- [ ] **Step 4:** 對真正的新 Supabase 專案跑一次匯入,並用 SQL 驗證筆數
```bash
export SUPABASE_URL=<你的新專案 URL>
export SUPABASE_SERVICE_ROLE_KEY=<service role key，僅在本機腳本使用，不可提交進 git>
python3 scripts/seed/seed_content.py
```
```sql
select count(*) from questions;  -- 應等於 Task 7 輸出的筆數
select count(*) from mnemonic_cards where source = 'original';
```
- [ ] **Step 5:** Commit(注意:不要把任何金鑰寫進程式碼或 commit)
```bash
git add scripts/seed/seed_content.py scripts/seed/test_seed_content.py
git commit -m "Add Supabase content seeding script for questions, chapters, and original mnemonic cards"
```

---

## Task 10: Wrong-book spaced-repetition state machine

**Files:**
- Modify: `lib/models/wrong_book.dart`
- Modify: `lib/repositories/user_data_repository.dart`
- Modify: `lib/core/database/shared_preferences_store.dart`(`addWrong` 擴充欄位 + 新增 `updateWrongBookEntry`)
- Modify: `lib/core/services/cloud_sync_service.dart`(新增 `updateWrong` 方法,寫入 `key_wrong_answers` 的 `correct_streak`/`next_review_date`)
- Test: `test/repositories/user_data_repository_wrongbook_test.dart`

**Interfaces:**
- Consumes: 既有 `SharedPreferencesStore`(本機優先存取)、`CloudSyncService`(背景同步到 Supabase `key_wrong_answers` 表,Task 2)
- Produces: `UserDataRepository.markReviewedCorrect(questionId)` / `markReviewedWrong(questionId)` / `getDueReviewCount()`,供 Task 11 的首頁提醒卡與複習模式呼叫

已知範圍限制(不在本任務修正):既有 `CloudSyncService.fetchWrongAnswers()`(app 啟動時把雲端錯題拉回新裝置用)只 select `question_id, wrong_count`,不會拉 `correct_streak`/`next_review_date`。換裝置登入後,還沒複習過的錯題會被當成「從沒複習過」(streak 0、明天到期),不會整支壞掉,只是複習排程在新裝置上會重算一輪。要做到完整跨裝置排程同步需要額外修改 `fetchWrongAnswers()` 與其呼叫端,超出本任務範圍。

- [ ] **Step 1:** 擴充 model
```dart
// lib/models/wrong_book.dart
class WrongBook {
  final int? id;
  final int questionId;
  final int wrongCount;
  final int correctStreak;
  final String lastWrongTime;
  final String nextReviewDate;  // ISO 8601 date, e.g. "2026-09-03"

  const WrongBook({
    this.id,
    required this.questionId,
    required this.wrongCount,
    required this.correctStreak,
    required this.lastWrongTime,
    required this.nextReviewDate,
  });

  factory WrongBook.fromMap(Map<String, dynamic> m) => WrongBook(
    id: m['id'],
    questionId: m['question_id'],
    wrongCount: m['wrong_count'],
    correctStreak: m['correct_streak'] ?? 0,
    lastWrongTime: m['last_wrong_time'],
    nextReviewDate: m['next_review_date'] ?? m['last_wrong_time'],
  );

  Map<String, dynamic> toMap() => {
    'question_id': questionId,
    'wrong_count': wrongCount,
    'correct_streak': correctStreak,
    'last_wrong_time': lastWrongTime,
    'next_review_date': nextReviewDate,
  };

  // 用純日期（不含時分秒）比較：nextReviewDate <= 今天才算到期。
  // 原本寫成 DateTime.now().add(Duration(days: 1)) 會讓「排到明天」的題目
  // 幾乎整天都被誤判成「今天就到期」（因為 nextReviewDate 解析出來是明天
  // 00:00:00，而比較基準是明天的當下時刻，前者幾乎必然早於後者）——等於
  // 才剛答錯排到隔天複習，馬上又被算進今日待複習，完全違背間隔複習的用意。
  bool get isDue {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    return !DateTime.parse(nextReviewDate).isAfter(todayMidnight);
  }
}
```
- [ ] **Step 2:** 寫失敗測試,涵蓋 spec §8.4 的三個狀態轉移
```dart
// test/repositories/user_data_repository_wrongbook_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:currency_insurance_exam/repositories/user_data_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('wrong answer resets streak and schedules review for tomorrow', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    final books = await repo.getWrongBooks();
    expect(books.first.correctStreak, 0);
    final expected = DateTime.now().add(const Duration(days: 1));
    expect(DateTime.parse(books.first.nextReviewDate).day, expected.day);
  });

  test('first correct review answer bumps streak and reschedules +3 days, stays in wrong book', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    await repo.markReviewedCorrect(1);
    final books = await repo.getWrongBooks();
    expect(books.length, 1);
    expect(books.first.correctStreak, 1);
    final expected = DateTime.now().add(const Duration(days: 3));
    expect(DateTime.parse(books.first.nextReviewDate).day, expected.day);
  });

  test('second consecutive correct review answer clears the question from wrong book', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    await repo.markReviewedCorrect(1);
    await repo.markReviewedCorrect(1);
    final books = await repo.getWrongBooks();
    expect(books, isEmpty);
  });

  test('a wrong answer mid-review resets streak instead of clearing', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    await repo.markReviewedCorrect(1);
    await repo.markReviewedWrong(1);
    final books = await repo.getWrongBooks();
    expect(books.first.correctStreak, 0);
  });

  test('normal practice mode answering correctly does not touch the streak', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1);
    await repo.recordPracticeAnswer(1, correct: true); // 一般練習作答，非複習模式
    final books = await repo.getWrongBooks();
    expect(books.first.correctStreak, 0);
  });
}
```
- [ ] **Step 3:** 確認失敗(`markReviewedCorrect`/`markReviewedWrong`/`recordPracticeAnswer` 尚未存在)
```bash
flutter test test/repositories/user_data_repository_wrongbook_test.dart
```
Expected: FAIL。
- [ ] **Step 4:** 實作狀態機
```dart
// lib/repositories/user_data_repository.dart（新增方法）
Future<void> markReviewedCorrect(int questionId) async {
  final books = await _store.getWrongBook();
  final entry = books[questionId.toString()];
  if (entry == null) return;
  final streak = (entry['correct_streak'] ?? 0) + 1;
  if (streak >= 2) {
    await removeWrong(questionId);
    return;
  }
  final nextReviewDate =
      DateTime.now().add(const Duration(days: 3)).toIso8601String().substring(0, 10);
  entry['correct_streak'] = streak;
  entry['next_review_date'] = nextReviewDate;
  await _store.updateWrongBookEntry(questionId, entry);
  unawaited(CloudSyncService.updateWrong(
    questionId.toString(),
    correctStreak: streak,
    nextReviewDate: nextReviewDate,
  ));
}

Future<void> markReviewedWrong(int questionId) async {
  await addWrong(questionId); // addWrong 已經會把 correct_streak 歸零、排到明天
}

Future<void> recordPracticeAnswer(int questionId, {required bool correct}) async {
  if (!correct) {
    await addWrong(questionId);
  }
  // 答對且非複習模式：不動 wrong_book 的 streak/排程（spec §8.4）
}

Future<int> getDueReviewCount() async {
  final books = await getWrongBooks();
  return books.where((b) => b.isDue).length;
}

Future<List<int>> getDueWrongQuestionIds() async {
  final books = await getWrongBooks();
  return books.where((b) => b.isDue).map((b) => b.questionId).toList();
}
```
`lib/core/database/shared_preferences_store.dart` 現有 `addWrong` 只寫 `question_id`/`wrong_count`/`last_wrong_time`,需擴充成同時寫入/重置 `correct_streak`/`next_review_date`,並新增 `updateWrongBookEntry`:
```dart
// lib/core/database/shared_preferences_store.dart（修改 addWrong，新增 updateWrongBookEntry）
Future<void> addWrong(int questionId) async {
  final data = await getWrongBook();
  final key = questionId.toString();
  final tomorrow = DateTime.now().add(const Duration(days: 1))
      .toIso8601String().substring(0, 10);
  if (data.containsKey(key)) {
    data[key]['wrong_count'] = (data[key]['wrong_count'] as int) + 1;
    data[key]['last_wrong_time'] = DateTime.now().toIso8601String();
  } else {
    data[key] = {
      'question_id': questionId,
      'wrong_count': 1,
      'last_wrong_time': DateTime.now().toIso8601String(),
    };
  }
  data[key]['correct_streak'] = 0;         // 新增：答錯一律歸零
  data[key]['next_review_date'] = tomorrow; // 新增：排到明天複習
  await _setMap(_kWrongBook, data);
}

Future<void> updateWrongBookEntry(int questionId, Map<String, dynamic> entry) async {
  final data = await getWrongBook();
  data[questionId.toString()] = entry;
  await _setMap(_kWrongBook, data);
}
```
`lib/core/services/cloud_sync_service.dart` 新增 `updateWrong`,寫法比照既有 `recordWrong` 的 upsert 模式,補上 `correct_streak`/`next_review_date` 兩欄:
```dart
// lib/core/services/cloud_sync_service.dart（新增方法）
/// 複習模式答對/答錯後同步 streak 與下次複習日到雲端
static Future<void> updateWrong(
  String questionId, {
  required int correctStreak,
  required String nextReviewDate,
}) async {
  if (!isLkMode) return;
  try {
    await _sb.from('key_wrong_answers').upsert({
      'key_id': _keyId,
      'device_id': _deviceId,
      'question_id': questionId,
      'correct_streak': correctStreak,
      'next_review_date': nextReviewDate,
    }, onConflict: 'key_id,device_id,question_id');
  } catch (_) {}
}
```
- [ ] **Step 5:** 補上 `isDue` 語意的直接單元測試,以及 `getDueWrongQuestionIds` 的測試(跟 Step 2 的其他案例合併在同一個測試檔內)。`isDue` 的正確語意是「`nextReviewDate` 為今天或更早才算到期」——直接用 model 建構子測邊界值,比透過 `addWrong`(只會排到明天)間接測更能鎖定這個語意,`addWrong` 那條路徑用來確認「剛排到明天的題目今天還不算到期」這個相反的斷言。
```dart
  test('isDue is true only when nextReviewDate is today or earlier', () {
    final today = DateTime.now();
    String dateStr(int offsetDays) =>
        today.add(Duration(days: offsetDays)).toIso8601String().substring(0, 10);

    final dueToday = WrongBook(questionId: 1, wrongCount: 1, correctStreak: 0,
        lastWrongTime: today.toIso8601String(), nextReviewDate: dateStr(0));
    final dueYesterday = WrongBook(questionId: 2, wrongCount: 1, correctStreak: 0,
        lastWrongTime: today.toIso8601String(), nextReviewDate: dateStr(-1));
    final notDueTomorrow = WrongBook(questionId: 3, wrongCount: 1, correctStreak: 0,
        lastWrongTime: today.toIso8601String(), nextReviewDate: dateStr(1));

    expect(dueToday.isDue, true);
    expect(dueYesterday.isDue, true);
    expect(notDueTomorrow.isDue, false);
  });

  test('getDueWrongQuestionIds excludes a question freshly scheduled for tomorrow', () async {
    final repo = UserDataRepository();
    await repo.addWrong(1); // next_review_date = 明天，今天還不算到期
    final ids = await repo.getDueWrongQuestionIds();
    expect(ids, isNot(contains(1)));
  });
```
- [ ] **Step 6:** 確認通過
```bash
flutter test test/repositories/user_data_repository_wrongbook_test.dart
```
Expected: 7 個測試全部 PASS。
- [ ] **Step 7:** Commit
```bash
git add lib/models/wrong_book.dart lib/repositories/user_data_repository.dart lib/core/database/shared_preferences_store.dart lib/core/services/cloud_sync_service.dart test/repositories/user_data_repository_wrongbook_test.dart
git commit -m "Add spaced-repetition state machine to wrong book (review-mode-only streak tracking)"
```

---

## Task 11: Home due-review badge + review mode (extend existing QuizPage)

現有 `QuizPage`(`lib/features/quiz/quiz_page.dart`)已經用 `isWrongBook`/`isFavorite` 兩個布林旗標支援「同一顆測驗元件、換一種題目來源與收尾行為」的模式,新增「複習模式」直接比照這個既有模式擴充,不另外開一個新頁面(避免重造一份幾乎一樣的作答 UI)。

**Files:**
- Modify: `lib/features/quiz/quiz_page.dart`(建構子 + `_loadQuestions` + `_submitAnswer` + `_saveProgressAndFinish` + AppBar 標題)
- Modify: `lib/app/router.dart:84-90`(`/quiz/:chapterId` 路由新增 `review` query 參數)
- Modify: `lib/features/home/home_page.dart`
- Test: `test/features/home/home_due_badge_test.dart`
- Test: `test/features/quiz/quiz_review_mode_test.dart`

**Interfaces:**
- Consumes: `UserDataRepository.getDueReviewCount()` / `getDueWrongQuestionIds()` / `markReviewedCorrect()` / `markReviewedWrong()`(Task 10)
- Produces: 首頁「📌 今日待複習 N 題」卡片,點擊導向 `/quiz/0?review=true`,沿用既有 `QuizPage` 的作答 UI,但送出答案時走複習模式的專屬邏輯

- [ ] **Step 1:** 寫失敗的 widget 測試(首頁徽章)
```dart
// test/features/home/home_due_badge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_insurance_exam/features/home/home_page.dart';
import 'package:currency_insurance_exam/providers/user_data_provider.dart';

void main() {
  testWidgets('shows due review count when greater than zero', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [dueReviewCountProvider.overrideWith((ref) async => 12)],
      child: const MaterialApp(home: HomePage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('今日待複習 12 題'), findsOneWidget);
  });

  testWidgets('hides the badge when due count is zero', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [dueReviewCountProvider.overrideWith((ref) async => 0)],
      child: const MaterialApp(home: HomePage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('今日待複習'), findsNothing);
  });
}
```
- [ ] **Step 2:** 確認失敗(`dueReviewCountProvider` 不存在)
```bash
flutter test test/features/home/home_due_badge_test.dart
```
Expected: FAIL。
- [ ] **Step 3:** 新增 provider 與首頁卡片
```dart
// lib/providers/user_data_provider.dart（新增）
final dueReviewCountProvider = FutureProvider<int>((ref) {
  return ref.read(userDataRepositoryProvider).getDueReviewCount();
});
```
```dart
// lib/features/home/home_page.dart（在既有 build 方法中插入）
Consumer(builder: (context, ref, _) {
  final due = ref.watch(dueReviewCountProvider);
  return due.when(
    data: (count) => count > 0
        ? Card(
            child: ListTile(
              leading: const Text('📌', style: TextStyle(fontSize: 24)),
              title: Text('今日待複習 $count 題',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              onTap: () => context.go('/quiz/0?review=true'),
            ),
          )
        : const SizedBox.shrink(),
    loading: () => const SizedBox.shrink(),
    error: (_, __) => const SizedBox.shrink(),
  );
}),
```
- [ ] **Step 4:** 確認徽章測試通過
```bash
flutter test test/features/home/home_due_badge_test.dart
```
Expected: PASS。
- [ ] **Step 5:** 寫失敗測試,驗證 `QuizPage` 的複習模式行為(答對呼叫 `markReviewedCorrect`、答錯呼叫 `markReviewedWrong`、且不影響章節 `progress`)。**注意**:`UserDataRepository.addWrong()` 一律把 `next_review_date` 排到明天(Task 10 修正 `isDue` 語意後的正確行為),所以不能像其他任務那樣單純呼叫 `addWrong(1)` 就假設題目「立刻到期」——這裡要直接寫入一筆 `next_review_date` 是昨天的錯題本紀錄,才能讓複習模式真的載入到這題。另外 `SharedPreferencesStore` 是手刻的 process-wide singleton(`_instance ??=`/`_prefs ??=`),同一個測試檔案裡第二次呼叫 `SharedPreferences.setMockInitialValues()` 對它不會生效——用 `SharedPreferencesStore.instance.prefs` 直接寫入才能確保每個測試互相隔離。
```dart
// test/features/quiz/quiz_review_mode_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:currency_insurance_exam/core/database/shared_preferences_store.dart';
import 'package:currency_insurance_exam/features/quiz/quiz_page.dart';
import 'package:currency_insurance_exam/providers/question_provider.dart';
import 'package:currency_insurance_exam/providers/user_data_provider.dart';
import 'package:currency_insurance_exam/repositories/question_repository.dart';
import 'package:currency_insurance_exam/repositories/user_data_repository.dart';
import '../../repositories/fakes/fake_supabase_content_source.dart';

Future<void> _seedDueWrongQuestion(int questionId) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferencesStore.instance.prefs;
  final yesterday = DateTime.now().subtract(const Duration(days: 1))
      .toIso8601String().substring(0, 10);
  await prefs.setString('wrong_book', '{"$questionId": {'
      '"question_id": $questionId, "wrong_count": 1, "correct_streak": 0, '
      '"last_wrong_time": "$yesterday", "next_review_date": "$yesterday"}}');
}

ProviderScope _harness({required Widget child}) {
  final fakeSource = FakeSupabaseContentSource(questionRows: [
    {
      'id': 1, 'chapter_id': 101, 'question_no': 1, 'question': '測試複習題目',
      'options': ['A', 'B', 'C', 'D'], 'answer': 1, 'explanation': '',
      'keyword_hint': null, 'plain_explanation': null, 'textbook_page': null,
    }
  ]);
  return ProviderScope(
    overrides: [
      questionRepositoryProvider.overrideWithValue(
        QuestionRepository(source: fakeSource, cache: ContentCacheStore.inMemory()),
      ),
    ],
    child: child,
  );
}

void main() {
  testWidgets('review mode title shows 今日複習 and does not touch chapter progress', (tester) async {
    await _seedDueWrongQuestion(1);
    final repo = UserDataRepository();

    await tester.pumpWidget(_harness(
      child: const MaterialApp(home: QuizPage(chapterId: 0, isReviewMode: true)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('今日複習'), findsOneWidget);
    // 先不作答，直接檢查目前 progress 沒有寫入 chapterId 0
    final progress = await repo.getProgress();
    expect(progress.containsKey(0), isFalse);
  });

  testWidgets('correct answer in review mode calls markReviewedCorrect (streak 0→1)', (tester) async {
    await _seedDueWrongQuestion(1);
    final repo = UserDataRepository();

    await tester.pumpWidget(_harness(
      child: const MaterialApp(home: QuizPage(chapterId: 0, isReviewMode: true)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A')); // 對應 answer: 1 的正確選項
    await tester.pumpAndSettle();

    final books = await repo.getWrongBooks();
    expect(books.first.correctStreak, 1); // 只有 markReviewedCorrect 會把 streak 推到 1
  });

  testWidgets('wrong answer in review mode calls markReviewedWrong (streak resets to 0)', (tester) async {
    await _seedDueWrongQuestion(1);
    final repo = UserDataRepository();

    await tester.pumpWidget(_harness(
      child: const MaterialApp(home: QuizPage(chapterId: 0, isReviewMode: true)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('B')); // 錯誤選項
    await tester.pumpAndSettle();

    final books = await repo.getWrongBooks();
    expect(books.first.correctStreak, 0); // markReviewedWrong 呼叫 addWrong，streak 歸零
  });
}
```
- [ ] **Step 6:** 確認失敗(`isReviewMode` 建構子參數尚不存在)
```bash
flutter test test/features/quiz/quiz_review_mode_test.dart
```
Expected: FAIL。
- [ ] **Step 7:** 擴充 `QuizPage`(建構子、資料來源、送出答案、收尾邏輯、標題)
```dart
// lib/features/quiz/quiz_page.dart
class QuizPage extends ConsumerStatefulWidget {
  final int chapterId;
  final bool isWrongBook;
  final bool isFavorite;
  final bool isReviewMode;             // 新增

  const QuizPage({
    super.key,
    required this.chapterId,
    this.isWrongBook = false,
    this.isFavorite = false,
    this.isReviewMode = false,         // 新增
  });
  // ...其餘不變
```
```dart
  Future<void> _loadQuestions() async {
    final repo = ref.read(questionRepositoryProvider);
    final userRepo = ref.read(userDataRepositoryProvider);
    List<Question> qs;

    if (widget.isReviewMode) {
      final dueIds = await userRepo.getDueWrongQuestionIds();
      qs = dueIds.isEmpty ? [] : await repo.getQuestionsByIds(dueIds);
    } else if (widget.isWrongBook) {
      final wrongIds = await userRepo.getWrongQuestionIds();
      qs = wrongIds.isEmpty ? [] : await repo.getQuestionsByIds(wrongIds);
    } else if (widget.isFavorite) {
      final favIds = await userRepo.getFavoriteIds();
      qs = favIds.isEmpty ? [] : await repo.getQuestionsByIds(favIds);
    } else {
      qs = await repo.getQuestionsByChapter(widget.chapterId);
    }
    // ...其餘不變（setState/_checkFav）
  }

  Future<void> _submitAnswer(int answer) async {
    if (_showAnswer) return;
    final q = _questions[_currentIndex];
    final isCorrect = answer == q.answer;
    final userRepo = ref.read(userDataRepositoryProvider);

    if (isCorrect) {
      _correctCount++;
    } else if (!widget.isReviewMode) {
      await userRepo.addWrong(q.id);
      ref.invalidate(wrongIdsProvider);
    }

    if (widget.isReviewMode) {
      if (isCorrect) {
        await userRepo.markReviewedCorrect(q.id);
      } else {
        await userRepo.markReviewedWrong(q.id);
      }
      ref.invalidate(dueReviewCountProvider);
    }

    setState(() {
      _selectedAnswer = answer;
      _showAnswer = true;
    });
  }

  Future<void> _saveProgressAndFinish() async {
    if (!widget.isWrongBook && !widget.isFavorite && !widget.isReviewMode) {
      await ref.read(userDataRepositoryProvider).updateProgress(
        widget.chapterId, _questions.length, _correctCount,
      );
      ref.invalidate(progressProvider);
    }
    // ...其餘 dialog 顯示邏輯不變
  }
```
AppBar 標題(原本的三元判斷 `isWrongBook ? '錯題本' : isFavorite ? '收藏題目' : ...`)最前面加一段:`widget.isReviewMode ? '今日複習' : ...`。
- [ ] **Step 8:** 路由加上 `review` 參數
```dart
// lib/app/router.dart（原本第 84–89 行附近）
GoRoute(
  path: '/quiz/:chapterId',
  builder: (_, state) => QuizPage(
    chapterId: int.parse(state.pathParameters['chapterId']!),
    isWrongBook: state.uri.queryParameters['wrong'] == 'true',
    isFavorite: state.uri.queryParameters['fav'] == 'true',
    isReviewMode: state.uri.queryParameters['review'] == 'true',  // 新增
  ),
),
```
- [ ] **Step 9:** 確認通過
```bash
flutter test test/features/quiz/quiz_review_mode_test.dart test/features/home/home_due_badge_test.dart
```
Expected: 全部 PASS。
- [ ] **Step 10:** 跑一次既有 quiz 測試,確認沒有把 `isWrongBook`/`isFavorite`/一般練習模式弄壞
```bash
flutter test test/features/quiz/
```
Expected: 全部 PASS。
- [ ] **Step 11:** Commit
```bash
git add lib/providers/user_data_provider.dart lib/features/home/home_page.dart lib/features/quiz/quiz_page.dart lib/app/router.dart test/features/home/home_due_badge_test.dart test/features/quiz/quiz_review_mode_test.dart
git commit -m "Add review-mode support to QuizPage and home due-review badge"
```

---

## Task 12: 18-level map — deterministic level breakdown

**Files:**
- Create: `scripts/extract/build_levels.py`
- Test: `scripts/extract/test_build_levels.py`

**Interfaces:**
- Consumes: `scripts/extract/output/questions_seeded.json`(Task 9 產出,含跟 Supabase 一致的 `id`)
- Produces: `scripts/extract/output/levels.json`,並直接寫入 Supabase `levels` 表(Task 9 執行時 `levels.json` 還不存在,所以匯入邏輯獨立寫在本任務,不依賴 Task 9 的 seed 腳本)

- [ ] **Step 1:** 寫失敗測試
```python
# scripts/extract/test_build_levels.py
from build_levels import build_levels

def test_splits_into_exactly_18_levels():
    questions = [{"id": i, "chapter_id": (i % 8) + 1} for i in range(1, 271)]
    levels = build_levels(questions, target_level_count=18)
    assert len(levels) == 18

def test_every_question_assigned_exactly_once():
    questions = [{"id": i, "chapter_id": (i % 8) + 1} for i in range(1, 271)]
    levels = build_levels(questions, target_level_count=18)
    all_ids = [qid for lvl in levels for qid in lvl["question_ids"]]
    assert sorted(all_ids) == list(range(1, 271))

def test_no_level_wildly_oversized_or_undersized():
    questions = [{"id": i, "chapter_id": (i % 8) + 1} for i in range(1, 271)]
    levels = build_levels(questions, target_level_count=18)
    sizes = [len(lvl["question_ids"]) for lvl in levels]
    assert min(sizes) >= 8
    assert max(sizes) <= 20
```
- [ ] **Step 2:** 確認失敗 → 實作(依章節題量比例分配關卡數,章節內部依 `question_no` 排序後平均切)
```python
# scripts/extract/build_levels.py
from collections import defaultdict

def build_levels(questions: list, target_level_count: int = 18):
    by_chapter = defaultdict(list)
    for q in questions:
        by_chapter[q["chapter_id"]].append(q["id"])
    for ids in by_chapter.values():
        ids.sort()

    total = len(questions)
    chapter_ids = sorted(by_chapter.keys())
    raw_allocation = {
        cid: max(1, round(len(by_chapter[cid]) / total * target_level_count))
        for cid in chapter_ids
    }
    # 調整總數精準等於 target_level_count（把差額加減在題量最大的章節）
    diff = target_level_count - sum(raw_allocation.values())
    if diff != 0:
        biggest = max(chapter_ids, key=lambda c: len(by_chapter[c]))
        raw_allocation[biggest] += diff

    levels, level_id = [], 1
    for cid in chapter_ids:
        ids = by_chapter[cid]
        n_levels = raw_allocation[cid]
        # 用 divmod 做平均切分，同一章節內每關題數最多只差 1 題。
        # 原本用 ceil(len(ids)/n_levels) 當固定 chunk_size 再逐段切，
        # 會讓除不盡時最後一關變成很小的「零頭」（例如 34 題切 4 關會變成
        # 9,9,9,7，最後一關明顯偏少）；divmod 讓題數分配平均攤在所有關卡上。
        base, remainder = divmod(len(ids), n_levels)
        start = 0
        for i in range(n_levels):
            size = base + (1 if i < remainder else 0)
            levels.append({
                "id": level_id,
                "order": level_id,
                "label": f"第{cid}章 第{i + 1}關",
                "chapter_id": cid,
                "question_ids": ids[start:start + size],
                "pass_threshold": 0.7,
            })
            start += size
            level_id += 1
    return levels
```
- [ ] **Step 3:** 確認通過
```bash
python3 -m pytest test_build_levels.py -v
```
Expected: 3 個測試全部 PASS。
- [ ] **Step 4:** 對真實資料跑,印出每關題數分布供人工過目
```python
# scripts/extract/run_build_levels.py
import json
from pathlib import Path
from build_levels import build_levels

questions = json.loads((Path(__file__).parent / "output/questions_seeded.json").read_text())
levels = build_levels(questions)
Path(__file__).parent.joinpath("output/levels.json").write_text(
    json.dumps(levels, ensure_ascii=False, indent=2))
print(f"共產生 {len(levels)} 關")
for lvl in levels:
    print(f"  {lvl['label']}: {len(lvl['question_ids'])} 題")
```
- [ ] **Step 5:** 把 `levels.json` 匯入 Supabase(此表在 Task 9 執行當下還沒有資料可匯,所以獨立成一支腳本)
```python
# scripts/seed/seed_levels.py
import json, os
from pathlib import Path
from supabase import create_client

def seed_levels():
    sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"])
    levels = json.loads(
        (Path(__file__).parent.parent / "extract/output/levels.json").read_text())
    sb.table("levels").upsert(levels).execute()
    return len(levels)

if __name__ == "__main__":
    n = seed_levels()
    print(f"seeded {n} levels")
```
```bash
export SUPABASE_URL=<你的新專案 URL>
export SUPABASE_SERVICE_ROLE_KEY=<service role key，僅在本機腳本使用，不可提交進 git>
python3 scripts/seed/seed_levels.py
```
```sql
select count(*) from levels;  -- 應等於 18
```
- [ ] **Step 6:** Commit
```bash
git add scripts/extract/build_levels.py scripts/extract/test_build_levels.py scripts/extract/run_build_levels.py scripts/seed/seed_levels.py
git commit -m "Add deterministic 18-level breakdown by chapter question volume and seed into Supabase"
```

---

## Task 13: 18-level map UI (soft-unlock)

**Files:**
- Create: `lib/features/levels/level_map_page.dart`
- Create: `lib/models/level.dart`
- Test: `test/features/levels/level_map_page_test.dart`

**Interfaces:**
- Consumes: Supabase `levels` 表(Task 12)、`level_progress` 表結構(Task 2)
- Produces: 一個路由 `/levels` 頁面,列出 18 關,綠燈狀態依 `level_progress.passed`

- [ ] **Step 1:** 寫失敗 widget 測試
```dart
// test/features/levels/level_map_page_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_insurance_exam/features/levels/level_map_page.dart';
import 'package:currency_insurance_exam/models/level.dart';
import 'package:currency_insurance_exam/providers/level_provider.dart';

void main() {
  testWidgets('all 18 levels are tappable regardless of progress (soft unlock)', (tester) async {
    final levels = List.generate(18, (i) => Level(
      id: i + 1, order: i + 1, label: '第$i關', chapterId: 1,
      questionIds: const [1, 2, 3], passThreshold: 0.7,
    ));
    await tester.pumpWidget(ProviderScope(
      overrides: [levelsProvider.overrideWith((ref) async => levels)],
      child: const MaterialApp(home: LevelMapPage()),
    ));
    await tester.pumpAndSettle();

    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(18));
    for (final tile in tiles.evaluate()) {
      final widget = tile.widget as ListTile;
      expect(widget.enabled, isTrue); // 沒有任何關卡因為順序被鎖住
    }
  });

  testWidgets('shows green light only for passed levels', (tester) async {
    final levels = [Level(id: 1, order: 1, label: '第1關', chapterId: 1,
        questionIds: const [1], passThreshold: 0.7)];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        levelsProvider.overrideWith((ref) async => levels),
        levelPassedProvider(1).overrideWith((ref) async => true),
      ],
      child: const MaterialApp(home: LevelMapPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('🟢'), findsOneWidget);
  });
}
```
- [ ] **Step 2:** 確認失敗
```bash
flutter test test/features/levels/level_map_page_test.dart
```
Expected: FAIL(`level.dart`/`level_provider.dart`/`level_map_page.dart` 都還不存在)。
- [ ] **Step 3:** 實作 model + provider + 頁面
```dart
// lib/models/level.dart
class Level {
  final int id, order, chapterId;
  final String label;
  final List<int> questionIds;
  final double passThreshold;
  const Level({required this.id, required this.order, required this.label,
      required this.chapterId, required this.questionIds, required this.passThreshold});

  factory Level.fromMap(Map<String, dynamic> m) => Level(
    id: m['id'], order: m['order'], label: m['label'], chapterId: m['chapter_id'],
    questionIds: List<int>.from(m['question_ids']),
    passThreshold: (m['pass_threshold'] as num).toDouble(),
  );
}
```
```dart
// lib/providers/level_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/level.dart';
import '../repositories/level_repository.dart';

final levelRepositoryProvider = Provider((ref) => LevelRepository());

final levelsProvider = FutureProvider<List<Level>>((ref) {
  return ref.read(levelRepositoryProvider).getLevels();
});

final levelPassedProvider = FutureProvider.family<bool, int>((ref, levelId) {
  return ref.read(levelRepositoryProvider).isLevelPassed(levelId);
});
```
```dart
// lib/repositories/level_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/level.dart';
import '../core/services/lk_auth_service.dart';

class LevelRepository {
  final _sb = Supabase.instance.client;
  List<Level>? _levels;

  Future<List<Level>> getLevels() async {
    if (_levels != null) return _levels!;
    final rows = await _sb.from('levels').select().order('order');
    _levels = List<Map<String, dynamic>>.from(rows).map(Level.fromMap).toList();
    return _levels!;
  }

  Future<bool> isLevelPassed(int levelId) async {
    final session = await LkAuthService.getSession();
    if (session == null) return false;
    final rows = await _sb
        .from('level_progress')
        .select('passed')
        .eq('key_id', session.keyId)
        .eq('device_id', session.deviceId)
        .eq('level_id', levelId)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows);
    return list.isNotEmpty && list.first['passed'] == true;
  }

  Future<void> saveLevelProgress(int levelId,
      {required int attempted, required int correct, required bool passed}) async {
    final session = await LkAuthService.getSession();
    if (session == null) return; // 未登入不寫入，不影響作答流程
    await _sb.from('level_progress').upsert({
      'key_id': session.keyId,
      'device_id': session.deviceId,
      'level_id': levelId,
      'attempted': attempted,
      'correct': correct,
      'passed': passed,
      'last_attempt_at': DateTime.now().toIso8601String(),
    }, onConflict: 'key_id,device_id,level_id');
  }
}
```
```dart
// lib/features/levels/level_map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/level_provider.dart';

class LevelMapPage extends ConsumerWidget {
  const LevelMapPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelsAsync = ref.watch(levelsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('18 關卡地圖')),
      body: levelsAsync.when(
        data: (levels) => ListView(
          children: levels.map((lvl) {
            final passedAsync = ref.watch(levelPassedProvider(lvl.id));
            return ListTile(
              enabled: true, // 軟解鎖：一律可點
              leading: Text(passedAsync.value == true ? '🟢' : '⚪',
                  style: const TextStyle(fontSize: 20)),
              title: Text(lvl.label, style: const TextStyle(fontSize: 18)),
              onTap: () => context.go('/quiz/0?levelId=${lvl.id}'),
            );
          }).toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('讀取失敗:$e')),
      ),
    );
  }
}
```
- [ ] **Step 4:** 確認通過
```bash
flutter test test/features/levels/level_map_page_test.dart
```
Expected: 2 個測試 PASS。
- [ ] **Step 5:** 把 `levelId` 接進 `QuizPage`(比照 Task 11 的 `isReviewMode` 模式:多一種題目來源,結束時多寫一筆 `level_progress`),並加測試
```dart
// test/features/quiz/quiz_level_mode_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_insurance_exam/features/quiz/quiz_page.dart';
import 'package:currency_insurance_exam/providers/level_provider.dart';
import 'package:currency_insurance_exam/models/level.dart';

void main() {
  testWidgets('level mode loads exactly the level\'s question ids', (tester) async {
    final level = Level(id: 1, order: 1, label: '第1關', chapterId: 1,
        questionIds: const [1, 2], passThreshold: 0.7);
    await tester.pumpWidget(ProviderScope(
      overrides: [levelByIdProvider(1).overrideWith((ref) async => level)],
      child: const MaterialApp(home: QuizPage(chapterId: 0, levelId: 1)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 1 題 / 共 2 題'), findsOneWidget);
  });
}
```
確認先跑會 FAIL(`levelId` 建構子參數、`levelByIdProvider` 都還不存在),再實作:
```dart
// lib/providers/level_provider.dart（新增）
final levelByIdProvider = FutureProvider.family<Level?, int>((ref, id) async {
  final levels = await ref.watch(levelsProvider.future);
  return levels.where((l) => l.id == id).firstOrNull;
});
```
```dart
// lib/features/quiz/quiz_page.dart
class QuizPage extends ConsumerStatefulWidget {
  final int chapterId;
  final bool isWrongBook;
  final bool isFavorite;
  final bool isReviewMode;
  final int? levelId;                // 新增

  const QuizPage({
    super.key,
    required this.chapterId,
    this.isWrongBook = false,
    this.isFavorite = false,
    this.isReviewMode = false,
    this.levelId,                    // 新增
  });
```
```dart
  Future<void> _loadQuestions() async {
    final repo = ref.read(questionRepositoryProvider);
    final userRepo = ref.read(userDataRepositoryProvider);
    List<Question> qs;

    if (widget.levelId != null) {
      final level = await ref.read(levelByIdProvider(widget.levelId!).future);
      qs = level == null ? [] : await repo.getQuestionsByIds(level.questionIds);
    } else if (widget.isReviewMode) {
      // ...(Task 11 既有分支)
    } // ...其餘分支不變
  }

  Future<void> _saveProgressAndFinish() async {
    if (widget.levelId != null) {
      final passed = _questions.isNotEmpty && (_correctCount / _questions.length) >= 0.7;
      await ref.read(levelRepositoryProvider).saveLevelProgress(
        widget.levelId!, attempted: _questions.length, correct: _correctCount, passed: passed,
      );
      ref.invalidate(levelPassedProvider(widget.levelId!));
    } else if (!widget.isWrongBook && !widget.isFavorite && !widget.isReviewMode) {
      // ...既有章節 progress 邏輯不變
    }
    // ...其餘 dialog 顯示邏輯不變
  }
```
`LevelRepository.saveLevelProgress()`/`isLevelPassed()` 已經在 Task 13 建立 `level_repository.dart` 時一併寫好,這裡直接呼叫即可。
- [ ] **Step 6:** 路由加上 `levelId` 參數
```dart
// lib/app/router.dart
GoRoute(
  path: '/quiz/:chapterId',
  builder: (_, state) => QuizPage(
    chapterId: int.parse(state.pathParameters['chapterId']!),
    isWrongBook: state.uri.queryParameters['wrong'] == 'true',
    isFavorite: state.uri.queryParameters['fav'] == 'true',
    isReviewMode: state.uri.queryParameters['review'] == 'true',
    levelId: state.uri.queryParameters['levelId'] != null
        ? int.parse(state.uri.queryParameters['levelId']!)
        : null,                                                    // 新增
  ),
),
```
- [ ] **Step 7:** 確認通過
```bash
flutter test test/features/quiz/quiz_level_mode_test.dart
flutter test test/features/quiz/  # 確認沒弄壞既有模式
```
Expected: 全部 PASS。
- [ ] **Step 8:** 補上首頁的入口(這步是這次審查才發現的缺口:整個計畫原本沒有任何一個任務把 `/levels` 掛到首頁,做完會是「功能存在但沒人找得到、只能手動打網址」)。比照 `lib/features/home/home_page.dart` 裡「錯題本」「收藏題目」等既有導覽項目的樣式與 `context.push`(不是 `context.go`——那些既有項目全部用 `push`,才能讓之後從測驗頁按「返回」正確回到首頁)新增一個「18關卡地圖」的入口,導到 `/levels`。同時把 `LevelMapPage` 裡從關卡卡片導到測驗頁的呼叫,從 `context.go('/quiz/0?levelId=${lvl.id}')` 改成 `context.push(...)`——用 `go` 會讓使用者答完一關後的返回鍵/手勢直接跳過關卡地圖(因為 `go` 會整個取代路由堆疊,不是疊上去),破壞「答完關卡回到地圖看到🟢再選下一關」這個地圖類 UI 最基本的操作迴圈。
```bash
flutter test  # 確認補上入口沒有弄壞任何既有測試
```
Expected: 全部 PASS。
- [ ] **Step 9:** Commit
```bash
git add lib/models/level.dart lib/providers/level_provider.dart lib/repositories/level_repository.dart lib/features/levels/level_map_page.dart lib/features/quiz/quiz_page.dart lib/features/home/home_page.dart lib/app/router.dart test/features/levels/level_map_page_test.dart test/features/quiz/quiz_level_mode_test.dart
git commit -m "Add 18-level gamified map with soft-unlock, wired into QuizPage and level_progress tracking"
```

---

## Task 14: Mnemonic card UI

**Files:**
- Create: `lib/features/mnemonics/mnemonic_card_list_page.dart`
- Create: `lib/models/mnemonic_card.dart`
- Create: `lib/repositories/mnemonic_repository.dart`
- Create: `lib/providers/mnemonic_provider.dart`
- Test: `test/features/mnemonics/mnemonic_card_list_page_test.dart`

**Interfaces:**
- Consumes: Supabase `mnemonic_cards` 表,僅讀 `approved = true` 的資料(Task 2 的 RLS policy 已在資料庫層擋掉未核准內容,前端不用再過濾一次,但測試仍要驗證 UI 對空清單/非空清單的行為)
- Produces: `/mnemonics` 路由頁面,可收藏(重用既有 `favoriteIdsProvider`/`toggleFavorite` 機制,收藏對象改成 `mnemonic_card_id` 而非 `question_id`——`favorites` 表需能同時存兩種型別,Task 2 schema 的 `favorites.question_id` 需改名為更泛用的 `item_id` + 新增 `item_type` 欄位;若嫌改動大,v1 可先只做「口訣卡列表瀏覽」,收藏功能留到下一輪再做,此處先實作瀏覽,收藏按鈕先隱藏)

- [ ] **Step 1:** 寫失敗測試
```dart
// test/features/mnemonics/mnemonic_card_list_page_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:currency_insurance_exam/features/mnemonics/mnemonic_card_list_page.dart';
import 'package:currency_insurance_exam/models/mnemonic_card.dart';
import 'package:currency_insurance_exam/providers/mnemonic_provider.dart';

void main() {
  testWidgets('renders phrase and meaning for each card', (tester) async {
    final cards = [
      MnemonicCard(id: '1', chapterId: 2, phrase: '金三角',
          meaning: ['外匯存款存放同一銀行不得超過資金3%'], source: 'original'),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [mnemonicCardsProvider.overrideWith((ref) async => cards)],
      child: const MaterialApp(home: MnemonicCardListPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('金三角'), findsOneWidget);
    expect(find.textContaining('資金3%'), findsOneWidget);
  });

  testWidgets('shows empty state when no approved cards exist yet', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [mnemonicCardsProvider.overrideWith((ref) async => const [])],
      child: const MaterialApp(home: MnemonicCardListPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('尚未有口訣卡'), findsOneWidget);
  });
}
```
- [ ] **Step 2:** 確認失敗(`mnemonic_provider.dart`/`mnemonic_card.dart`/`mnemonic_card_list_page.dart` 都還不存在)
```bash
flutter test test/features/mnemonics/mnemonic_card_list_page_test.dart
```
Expected: FAIL。
- [ ] **Step 3:** 實作 model/repository/provider/頁面
```dart
// lib/models/mnemonic_card.dart
class MnemonicCard {
  final String id;
  final int chapterId;
  final String phrase;
  final List<String> meaning;
  final String source;
  const MnemonicCard({required this.id, required this.chapterId,
      required this.phrase, required this.meaning, required this.source});

  factory MnemonicCard.fromMap(Map<String, dynamic> m) => MnemonicCard(
    id: m['id'], chapterId: m['chapter_id'], phrase: m['phrase'],
    meaning: List<String>.from(m['meaning']), source: m['source'],
  );
}
```
```dart
// lib/repositories/mnemonic_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mnemonic_card.dart';

class MnemonicRepository {
  final _sb = Supabase.instance.client;

  Future<List<MnemonicCard>> getApprovedCards() async {
    // approved=true 已經由 Task 2 的 RLS policy 在資料庫層強制，這裡不用再過濾一次
    final rows = await _sb.from('mnemonic_cards').select();
    return List<Map<String, dynamic>>.from(rows).map(MnemonicCard.fromMap).toList();
  }
}
```
```dart
// lib/providers/mnemonic_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mnemonic_card.dart';
import '../repositories/mnemonic_repository.dart';

final mnemonicRepositoryProvider = Provider((ref) => MnemonicRepository());

final mnemonicCardsProvider = FutureProvider<List<MnemonicCard>>((ref) {
  return ref.read(mnemonicRepositoryProvider).getApprovedCards();
});
```
```dart
// lib/features/mnemonics/mnemonic_card_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/mnemonic_provider.dart';

class MnemonicCardListPage extends ConsumerWidget {
  const MnemonicCardListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(mnemonicCardsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('口訣卡')),
      body: cardsAsync.when(
        data: (cards) => cards.isEmpty
            ? const Center(child: Text('尚未有口訣卡,持續新增中'))
            : ListView(children: cards.map((c) => Card(
                child: ListTile(
                  title: Text(c.phrase,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text(c.meaning.join('\n'),
                      style: const TextStyle(fontSize: 16, height: 1.6)),
                ),
              )).toList()),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('讀取失敗:$e')),
      ),
    );
  }
}
```
- [ ] **Step 4:** 確認通過
```bash
flutter test test/features/mnemonics/mnemonic_card_list_page_test.dart
```
Expected: 2 個測試 PASS。
- [ ] **Step 5:** Commit
```bash
git add lib/models/mnemonic_card.dart lib/repositories/mnemonic_repository.dart lib/providers/mnemonic_provider.dart lib/features/mnemonics/mnemonic_card_list_page.dart test/features/mnemonics/mnemonic_card_list_page_test.dart
git commit -m "Add mnemonic card browsing page (favorites deferred to a later iteration)"
```

---

## Task 15: Keyword hint + plain explanation UI in quiz results

**Files:**
- Modify: `lib/features/quiz/quiz_page.dart:232-249`(原本內嵌渲染「解析」的 `Container` 區塊,整段換成 `ExplanationPanel(question: q)`)
- Create: `lib/features/quiz/widgets/explanation_panel.dart`
- Test: `test/features/quiz/quiz_explanation_sections_test.dart`

**Interfaces:**
- Consumes: `Question.keywordHint`/`Question.plainExplanation`(Task 3 的 model 擴充)
- Produces: 作答後除了原本法規式 `explanation`,多顯示兩個可展開區塊;若 `plainExplanation` 為空(尚未產製,見 Task 17),則不顯示白話區塊,只顯示關鍵字破題

- [ ] **Step 1:** 寫失敗測試
```dart
// test/features/quiz/quiz_explanation_sections_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:currency_insurance_exam/features/quiz/widgets/explanation_panel.dart';
import 'package:currency_insurance_exam/models/question.dart';

void main() {
  testWidgets('shows keyword hint and plain explanation when both present', (tester) async {
    final q = Question(id: 1, chapterId: 1, questionNo: 1, question: 'q',
        options: const ['a','b','c','d'], answer: 1, explanation: '法規解析',
        keywordHint: '結匯→向銀行業辦理', plainExplanation: '白話說明文字', textbookPage: 23);
    await tester.pumpWidget(MaterialApp(home: ExplanationPanel(question: q)));
    expect(find.textContaining('🎯 關鍵字破題'), findsOneWidget);
    expect(find.textContaining('結匯→向銀行業辦理'), findsOneWidget);
    expect(find.textContaining('💬 白話告訴你為什麼'), findsOneWidget);
  });

  testWidgets('hides plain explanation section when not yet generated', (tester) async {
    final q = Question(id: 1, chapterId: 1, questionNo: 1, question: 'q',
        options: const ['a','b','c','d'], answer: 1, explanation: '法規解析',
        keywordHint: '提示', plainExplanation: null, textbookPage: 23);
    await tester.pumpWidget(MaterialApp(home: ExplanationPanel(question: q)));
    expect(find.textContaining('🎯 關鍵字破題'), findsOneWidget);
    expect(find.textContaining('💬 白話告訴你為什麼'), findsNothing);
  });
}
```
- [ ] **Step 2:** 確認失敗(`ExplanationPanel` 不存在)
```bash
flutter test test/features/quiz/quiz_explanation_sections_test.dart
```
Expected: FAIL。
- [ ] **Step 3:** 實作為獨立元件(抽出來方便測試,`quiz_page.dart` 原本渲染解析的地方改成呼叫這個元件)
```dart
// lib/features/quiz/widgets/explanation_panel.dart
import 'package:flutter/material.dart';
import '../../../models/question.dart';

class ExplanationPanel extends StatelessWidget {
  final Question question;
  const ExplanationPanel({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 16, height: 1.6);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (question.keywordHint != null && question.keywordHint!.isNotEmpty)
        ExpansionTile(
          title: const Text('🎯 關鍵字破題', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          children: [Padding(padding: const EdgeInsets.all(12),
              child: Text(question.keywordHint!, style: textStyle))],
        ),
      if (question.plainExplanation != null && question.plainExplanation!.isNotEmpty)
        ExpansionTile(
          title: const Text('💬 白話告訴你為什麼', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          children: [Padding(padding: const EdgeInsets.all(12),
              child: Text(question.plainExplanation!, style: textStyle))],
        ),
      Padding(padding: const EdgeInsets.all(12),
          child: Text('📖 法規解析:${question.explanation}', style: textStyle)),
    ]);
  }
}
```
- [ ] **Step 4:** 確認通過
```bash
flutter test test/features/quiz/quiz_explanation_sections_test.dart
```
Expected: 2 個測試 PASS。
- [ ] **Step 5:** 在 `quiz_page.dart:232-249` 把原本內嵌渲染解析的 `Container`(標題「解析」+ `Text(q.explanation, ...)`)整段刪除,換成 `if (_showAnswer) ExplanationPanel(question: q),`,跑一次既有的 quiz 相關測試確保沒有壞掉既有行為
```bash
flutter test test/features/quiz/
```
Expected: 全部 PASS。
- [ ] **Step 6:** Commit
```bash
git add lib/features/quiz/widgets/explanation_panel.dart lib/features/quiz/quiz_page.dart test/features/quiz/quiz_explanation_sections_test.dart
git commit -m "Add keyword-hint and plain-explanation panels to quiz result view"
```

---

## Task 16: Guide slide deck → page images + chapter page-range viewer data

**Files:**
- Create: `scripts/extract/convert_guide_images.sh`
- Create: `scripts/extract/build_guide_pages.py`
- Test: `scripts/extract/test_build_guide_pages.py`

**Interfaces:**
- Consumes: `~/Documents/外幣/外幣證照必勝寶典_授課簡報V1.pdf`(263頁)、`chapter_page_ranges.json`(Task 7)
- Produces: `assets/images/guide/guide_pXXX.png`(263張)、`assets/json/guide_pages.json`(比照壽險版格式,供既有教材翻頁閱讀器元件直接重用,不需改 UI 程式碼)

- [ ] **Step 1:** 轉圖(機械操作,無需先寫測試,但轉完要斷言張數)
```bash
# scripts/extract/convert_guide_images.sh
#!/bin/bash
set -euo pipefail
SRC=~/Documents/外幣/外幣證照必勝寶典_授課簡報V1.pdf
OUT=/Users/fortune/currency-insurance-exam/assets/images/guide
mkdir -p "$OUT"
pdftoppm -png -r 150 "$SRC" "$OUT/guide_p"
COUNT=$(ls "$OUT"/guide_p*.png | wc -l | tr -d ' ')
echo "converted $COUNT pages"
test "$COUNT" -eq 263
```
Run: `bash scripts/extract/convert_guide_images.sh`
Expected: 印出 `converted 263 pages`,腳本本身用 `test` 斷言張數,不符合會直接失敗(exit code 非 0)。
- [ ] **Step 2:** 寫失敗測試(guide_pages.json 產生邏輯)
```python
# scripts/extract/test_build_guide_pages.py
from build_guide_pages import build_guide_pages

def test_builds_page_ranges_keyed_by_chapter():
    ranges = [
        {"chapter_id": 1, "title": "外幣保險開放紀事", "page_start": 5, "page_end": 8},
        {"chapter_id": 2, "title": "保險業辦理外匯業務管理辦法", "page_start": 9, "page_end": 15},
    ]
    result = build_guide_pages(ranges)
    assert result["chapters"]["1"]["pages"] == [5, 6, 7, 8]
    assert result["chapters"]["1"]["label"] == "外幣保險開放紀事"
    assert result["chapters"]["2"]["pages"] == [9, 10, 11, 12, 13, 14, 15]
```
- [ ] **Step 3:** 確認失敗 → 實作(格式對齊壽險版 `guide_pages.json` 的 `{chapters: {chapterId: {pages, label}}}` 結構)
```python
# scripts/extract/build_guide_pages.py
def build_guide_pages(ranges: list) -> dict:
    chapters = {}
    for r in ranges:
        chapters[str(r["chapter_id"])] = {
            "pages": list(range(r["page_start"], r["page_end"] + 1)),
            "label": r["title"],
        }
    return {"intro": {"pages": [1, 2, 3, 4], "label": "課程引言"}, "chapters": chapters}
```
- [ ] **Step 4:** 確認通過
```bash
python3 -m pytest test_build_guide_pages.py -v
```
Expected: PASS。
- [ ] **Step 5:** 對真實 `chapter_page_ranges.json` 跑,輸出到 `assets/json/guide_pages.json`
```python
# scripts/extract/run_build_guide_pages.py
import json
from pathlib import Path
from build_guide_pages import build_guide_pages

ranges = json.loads((Path(__file__).parent / "chapter_page_ranges.json").read_text())
result = build_guide_pages(ranges)
out = Path("/Users/fortune/currency-insurance-exam/assets/json/guide_pages.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, ensure_ascii=False, indent=2))
print(f"guide_pages.json written, {len(result['chapters'])} chapters")
```
- [ ] **Step 6:** Commit(圖片檔案量大,確認 `.gitignore` 或 git-lfs 策略再 commit;若暫不確定,先跟我確認要不要把 263 張圖進 git 還是改放物件儲存)
```bash
git add scripts/extract/convert_guide_images.sh scripts/extract/build_guide_pages.py scripts/extract/test_build_guide_pages.py scripts/extract/run_build_guide_pages.py assets/json/guide_pages.json
git commit -m "Add guide slide deck to page-image conversion and chapter page-range mapping"
```

---

## Task 17: `plain_explanation` batch generation (human-reviewed content)

這個任務性質跟前面不同:不是寫程式邏輯,而是**產出內容**,所以驗收標準是「產出+人工覆核簽核」,不是單元測試通過。

**Files:**
- Create: `scripts/generate/plain_explanation_batch.md`(每批次的操作紀錄與覆核簽核表)
- Modify: Supabase `questions.plain_explanation` / `questions.plain_explanation_reviewed`(逐章節更新)

- [ ] **Step 1:** 依 8 大章節分批,每批次(一個章節)由我(執行任務的 agent)根據 `question/options/answer/explanation/keyword_hint` 生成白話解釋,規則:
  - 只解釋「為什麼答案是對的、其他選項為什麼錯」,不新增法規未提及的內容
  - 禁止使用「根據法規」「依規定」等重複贅詞開頭,直接講因果
  - 每則 80–150 字繁體中文
- [ ] **Step 2:** 每批次產出後,寫一份對照表(題號 + 原法規解析 + 新白話解析)存到 `scripts/generate/output/chapter_<N>_plain_explanations.json`,並在 `plain_explanation_batch.md` 記錄本批次涵蓋題號範圍
- [ ] **Step 3:** 呈交給你逐題(至少抽樣 20%)覆核法規正確性,你確認後才把該批次的 `plain_explanation_reviewed` 從 `false` 改成 `true`,未覆核前 UI 不顯示(Task 15 已經用 `plainExplanation != null` 判斷,若要更嚴謹可以改成同時檢查 `reviewed` 欄位——實作時把 `SupabaseContentSource.fetchQuestions()` 的 select 過濾條件加上 `plain_explanation_reviewed=true` 才回傳給 UI)
- [ ] **Step 4:** 覆核通過的批次寫入 Supabase(用 Task 9 的 seed 腳本模式,新增一個 `update_plain_explanations.py` 做局部 upsert)並記錄進度
- [ ] **Step 5:** Commit 每批次的產出檔案(不包含尚未覆核通過的內容上線,只是進 git 版控)
```bash
git add scripts/generate/plain_explanation_batch.md scripts/generate/output/chapter_<N>_plain_explanations.json
git commit -m "Add plain-language explanations for chapter <N> (pending human review before going live)"
```

---

## Task 18: `ai_generated` mnemonic cards for uncovered numeric/list rules

同樣屬於內容產製任務,驗收標準是人工覆核簽核。

**Files:**
- Create: `scripts/generate/ai_mnemonics_batch.md`
- Modify: Supabase `mnemonic_cards`(新增 `source='ai_generated', approved=false` 的候選卡片)

- [ ] **Step 1:** 找出題庫裡「有明確數字/清單但沒有 Task 5 抓到既有口訣」的題目(用 `questions_needs_review` 之外、`explanation` 含「百分之」「日」「年」等數字但不含「口訣」字樣的題目做候選清單)
- [ ] **Step 2:** 依照題庫原有口訣的風格(單字/雙字濃縮,如「金三角」「十權」)新創口訣,標記 `source: ai_generated, approved: false`
- [ ] **Step 3:** 交你逐張覆核法規正確性與好記程度,核准的才把 `approved` 改 `true`(Task 2 的 RLS policy 已經確保 `approved=false` 的卡片不會出現在 app 前台,不用擔心誤上線)
- [ ] **Step 4:** Commit 候選清單檔案

---

## Task 19: Integration smoke test + deploy

**Files:**
- Create: `scripts/smoke_test.sh`

**Interfaces:**
- Consumes: 前面所有任務完成後的完整 app + 已 seed 的 Supabase

- [ ] **Step 1:** 本機建置並手動走一次關鍵路徑(登入 → 練習 → 錯題本複習 → 口訣卡 → 18關地圖)
```bash
cd /Users/fortune/currency-insurance-exam
flutter build web
```
- [ ] **Step 2:** 確認全部自動化測試通過
```bash
flutter test
cd scripts/extract && python3 -m pytest -v
```
Expected: 全部 PASS。
- [ ] **Step 3:** 部署到 GitHub Pages(比照壽險版 deploy 慣例:web build 產物 commit 到對應分支或用 GitHub Actions)——實際部署方式待你確認 repo 要不要開在 `shinkong-insurance` org、以及沿用哪種既有 deploy 流程後再執行,此步驟先不自動跑
- [ ] **Step 4:** Commit
```bash
git add scripts/smoke_test.sh
git commit -m "Add integration smoke test script"
```
