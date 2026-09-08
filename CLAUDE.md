# 外幣保險資格測驗 App

Flutter Web 考照練習 App（外幣保險資格測驗，沿用壽險版 `insurance-exam-app`
的架構：LK 授權碼登入、Supabase 內容、本機優先同步）。

**開始接手作業前，先讀 [`docs/DEPLOYMENT_RUNBOOK.md`](docs/DEPLOYMENT_RUNBOOK.md)**
——這份文件假設你對這個 repo 完全沒有記憶，寫了完整現況、已知問題、和
每一步實際指令，不要憑印象或猜測跳過它。

## 目前狀態速覽（詳細見 runbook 最上面）

- **2026-09-08 新增**：後台管理 `web/admin.html`（授權碼管理 + 學員管理，比照壽險版
  `insurance-exam-app/web/admin.html`）。管理員帳號 `admin@skl.com.tw` 已建立並
  實測登入成功，過程中修正 2 個 schema 落差（新增 `students` 表、
  `license_keys` 補 `notes` 欄位、`loadKeys()` 排序欄位改用 `expires_at`）。
  **還沒 build+部署**，細節見 runbook 最上面。
- **已正式上線**：https://shinkong-insurance.github.io/currency-insurance-exam/
  （GitHub repo：https://github.com/shinkong-insurance/currency-insurance-exam，
  `main` 放原始碼、`gh-pages` 放建置後的靜態網頁）
- **118 題題庫**（2026-09-08 前是 126 題，考生實測回報「同樣的題目會重複」，
  查證後刪除 8 組真的逐字重複的題目，見下方「還沒做的事」）、8 章、18 關卡、
  2 張原文口訣卡已灌進 Supabase；125/126 題白話解析已核准（刪掉的 8 題都在
  已核准的那 125 題裡，實際剩 117 題有白話解析）
- **Supabase 專案的 URL/API key 沒有存在這個 repo 或任何檔案裡**（刻意不
  存，避免 secret 外洩）——需要接手的人自己去 Supabase Dashboard 查，或問
  持有帳號的人要
- 測試授權碼：`SK-2026-TEST-0001`（無限次使用，2026-12-31 到期）

## 還沒做的事

- **抽取管線本身沒修**：這次只刪了 Supabase 正式資料庫裡的 8 筆重複題
  （`supabase/migrations/0005_remove_duplicate_questions.sql`），沒有動
  `scripts/extract`/`scripts/generate` 的程式碼或 `scripts/seed/question_id_registry.json`。
  代表如果之後從頭重新 `seed_content.py`（例如換一個新 Supabase 專案），
  這 8 筆重複題會原封不動再灌回去一次。真正的根源是原始題庫 PDF 的「新增」
  (E) 卷逐字重複了 A/B/C 卷已出過的題目，要澈底修得回到抽取階段依「題目文字
  完全相同」做去重（照專案慣例：先寫測試再改 `scripts/extract`）。
- 10 張 AI 口訣候選卡的人工核准（`scripts/generate/ai_mnemonics_approval_checklist.md`）
- 4 句原文口訣裡有 2 句（週三日一、金三角）因來源題目沒被分類到章節而沒灌進資料庫
- id 122（新增-9，ch6）缺白話解析，課程簡報裡找不到依據，需對照正式法規全文
- 上線前應該把測試授權碼換成正式批次

## 開發慣例

- Python 抽取/種子腳本（`scripts/extract`、`scripts/generate`、`scripts/seed`）
  一律先寫測試再實作，每個腳本目錄下都有對應 `pytest`
- `scripts/extract/output/*.json` 是本機執行期產物，不進 git，需要時照
  `scripts/extract/v3_pdf_update_2026-09-04.md` 文末的指令重新產生
- Flutter 端改動後跑 `flutter analyze`（0 error）+ `flutter test`（38 tests）
- 部署到 GitHub Pages 記得帶 `--base-href /currency-insurance-exam/`，細節
  見 runbook 步驟 5
