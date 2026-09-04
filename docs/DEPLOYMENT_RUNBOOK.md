# 外幣保險資格測驗 App — 上線作業指南

給下一次接續作業時（不管是您自己動手，還是請 Claude 接續）使用。這份文件假設
執行者對這個 repo 完全沒有記憶，所以每一步都寫實際指令，不寫「請自行判斷」。

## 目前狀態（2026-09-03）

- 19 個開發任務 + 最終全分支審查 + 一輪修正都已完成。分支
  `worktree-currency-exam-build`（worktree 路徑：
  `/Users/fortune/currency-insurance-exam/.claude/worktrees/currency-exam-build`）
  乾淨、測試全綠：`flutter test` 35/35、`scripts/extract` pytest 21/21、
  `scripts/seed` pytest 1/1、`scripts/generate` pytest 2/2、`flutter analyze` 0 錯誤。
- **這個分支還沒 merge 回 `master`**（本地 merge 因為 Claude 這次的 worktree
  沙盒隔離無法從這個 session 直接操作主目錄，需要您自己跑，見下方步驟 0）。
- **沒有真正的 Supabase 雲端專案**——全程用本機開發環境驗證，`lib/core/services/supabase_config.dart`
  目前是明確的佔位字串 `REPLACE_ME`，必須換成您自己申請的專案資訊。
- **沒有正式部署網址**——Task 19 的部署步驟刻意保留給您決定（部署平台 / repo org）。
- **114 題白話解析（plain_explanation）已產出但未核准**（`plain_explanation_reviewed=false`），
  **10 張 AI 口訣候選卡未核准也未寫入資料庫**（`ai_mnemonics_batch.md`，尚未 insert）。
- **教材翻頁閱讀器沒有接上**（Task 16 產出的 263 張圖片目前沒有任何畫面在讀取，
  已知落後於 spec 原意，見下方「已知落後項目」）。
- **RLS 風險提醒**：目前 schema 對使用者資料表（license_keys 等）沒有 ownership
  層級的 RLS，任何持有 anon key 的人都能讀取全部授權碼、寫入任何學員的答題紀錄。
  這是延續壽險版既有設計，但正式上線前建議您重新評估這個風險是否可接受。

---

## 步驟 0：先把分支 merge 回 master（在您自己的終端機執行）

這個 Claude session 被限制只能對它自己的 worktree 做 git 操作，無法切換到主
目錄執行 merge。麻煩您自己執行（或用 `!` 開頭讓 Claude 在您的終端機代跑）：

```bash
cd /Users/fortune/currency-insurance-exam
git checkout master
git merge worktree-currency-exam-build
flutter test   # 應該還是 35/35 全過
```

merge 成功且測試綠燈後，可選擇性清掉 worktree：

```bash
git worktree remove .claude/worktrees/currency-exam-build
git worktree prune
git branch -d worktree-currency-exam-build
```

（沒有 remote，所以沒有 push/PR 這個選項——如果之後想開 GitHub repo 放這個專案，
那是另一個獨立決定，見步驟 5。）

---

## 步驟 1：申請正式 Supabase 專案（需要您本人登入，Claude 無法代做）

1. 到 https://supabase.com/dashboard 用您的帳號登入（或註冊新帳號）。
2. 建立新專案，**不要**選到壽險版正在用的那個專案——這次要獨立一個新專案
   （spec 明確要求：不共用壽險的 Supabase 專案）。
3. 專案建好後，到 Project Settings → API，記下三個值：
   - `Project URL`（例如 `https://xxxxxxxx.supabase.co`）
   - `anon public` key
   - `service_role` key（⚠️ 這個 key 有完整資料庫寫入權限，只用在下面的種子腳本，
     不要放進 Flutter app 或任何前端程式碼）

## 步驟 2：套用 schema migration

```bash
cd /Users/fortune/currency-insurance-exam   # merge 完之後 master 就有完整程式碼
export SUPABASE_ACCESS_TOKEN=<在 Supabase Dashboard → Account → Access Tokens 產生>
supabase link --project-ref <您的 project ref，網址列 xxxxxxxx 那一段>
supabase db push   # 套用 supabase/migrations/0001_init_schema.sql
```

如果 `supabase db push` 有問題，備案是直接把
`supabase/migrations/0001_init_schema.sql` 的內容貼到 Supabase Dashboard 的
SQL Editor 執行一次。

## 步驟 3：灌資料（章節、題目、口訣、關卡）

```bash
export SUPABASE_URL=https://xxxxxxxx.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=<步驟1記下的 service_role key>

cd scripts/seed
pip install supabase   # 如果這台機器還沒裝過
python3 seed_content.py   # 灌 course/chapters/questions/mnemonic_cards(original)
python3 seed_levels.py    # 灌 18 關卡資料
```

預期輸出類似：
```
seeded 114 questions, 2 mnemonic cards
seeded 18 levels
```
（2 張口訣卡是 Task 5 抓到的原始口訣，AI 生成的 10 張候選卡不在這裡，見步驟 4b。）

## 步驟 4：白話解析 + AI 口訣卡的人工核准

### 4a. 白話解析（114 題，已有腳本可用）

先自己（或請可信任的人）核對至少 20% 的內容，對照
`scripts/generate/plain_explanation_batch.md` 和對應章節的
`scripts/generate/output/chapter_<N>_plain_explanations.json`（N = 2,3,4,5,6,7）。
**已先做過一輪自動抽查，結果見 `scripts/generate/plain_explanation_spotcheck_2026-09-04.md`
——裡面列出 21 題「原始說明是空的」高風險清單（建議優先全查，不要只抽 20%）
跟一個確定的格式缺陷（id 100），麻煩從那份報告的建議處理順序開始。**
確認沒問題後，逐章節執行：

```bash
export SUPABASE_URL=https://xxxxxxxx.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=<service_role key>
cd scripts/generate
python3 update_plain_explanations.py 2 --approve
python3 update_plain_explanations.py 3 --approve
python3 update_plain_explanations.py 4 --approve
python3 update_plain_explanations.py 5 --approve
python3 update_plain_explanations.py 6 --approve
python3 update_plain_explanations.py 7 --approve
```

不加 `--approve` 可以先只寫入草稿內容但不讓 app 顯示（`plain_explanation_reviewed`
維持 false），方便分批處理。

### 4b. AI 口訣卡候選（10 張，只有文件沒有腳本——手動處理即可，量少不值得寫程式）

打開 `scripts/generate/ai_mnemonics_approval_checklist.md`（依風險由低到高
排好序的精簡核准表，比原始 `ai_mnemonics_batch.md` 好操作，技術細節仍留在
後者），逐張核對 10 個候選（規範正確性 + 好不好記）。核准的，直接在
Supabase Dashboard 的
Table Editor 開 `mnemonic_cards` 表手動新增一列：`phrase`、`meaning`（陣列）、
`chapter_id`、`related_question_ids`（陣列，題目 id 從
`scripts/extract/output/questions_seeded.json` 查 `(exam_set, question_no)`
對應的 id）、`source='ai_generated'`、`approved=true`。不核准的就不動作
（RLS 已確保 `approved=false` 的卡片不會出現在 app 前台）。

## 步驟 5：build + 部署

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://xxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<步驟1記下的 anon key>
```

部署平台待您決定（plan 原本預設比照壽險版走 GitHub Pages，但這是您的選擇，
不是既定事實）：
- **GitHub Pages**（比照壽險版慣例）：需要決定要不要開在 `shinkong-insurance`
  這個 org 底下，以及要用既有的哪種 deploy 流程（GitHub Actions 自動 build，
  或手動把 `build/web` 產物 commit 到 `gh-pages` 分支）。
- 其他選項：Vercel / Netlify / Firebase Hosting 都能直接吃 `build/web` 這個
  靜態資料夾，設定上更簡單，但跟壽險版不一致。

## 步驟 6：發第一組測試授權碼

在 Supabase Table Editor 開 `license_keys` 表，新增一列：

| 欄位 | 範例值 |
|---|---|
| key_code | `SK-TEST-0001-0001` |
| batch_name | `測試批次` |
| max_uses | `1`（或 `0` = 無限次） |
| expires_at | 例如 `2026-12-31T23:59:59+08:00` |
| is_active | `true` |

用這組授權碼在 build 出來的網頁上走一次完整流程：登入 → 章節閱讀 → 練習 →
錯題本複習 → 口訣卡 → 18 關地圖 → 模擬測驗，確認每個入口都正常。

---

## 已知落後項目（上線前建議一併決定，但不阻擋上線）

1. **教材翻頁閱讀器沒接上**——`assets/images/guide/`（Task 16 產出的 263 張圖）
   跟 `assets/json/guide_pages.json` 目前沒有任何畫面讀取；真正的閱讀器元件讀的
   是另一個從未被 seed 過的 `assets/json/section_images.json`。這在 spec 第 4
   節有明確提到要保留這個功能，是一個真實落差，建議另外排一個小任務補上，
   不是單靠這份 runbook 能處理的範圍。
2. **RLS 風險**（見上方「目前狀態」）——一旦真的接上正式 Supabase 專案，這個
   風險就是真的，不是假設性的。建議上線前重新確認是否接受。
3. 口訣卡文案（步驟 4b 那 10 張）用的是原始題庫掃描文字，包含頁碼引用跟斷行，
   核准前建議順手潤一下文字。
4. `web/student-guide.html`（考生使用手冊）目前內容還是壽險版的（13章、兩科
   140分規則等），需要重寫成外幣版的實際章節/規則。
