# 外幣保險資格測驗 App

Flutter Web 考照練習 App（外幣保險資格測驗，沿用壽險版 `insurance-exam-app`
的架構：LK 授權碼登入、Supabase 內容、本機優先同步）。

**開始接手作業前，先讀 [`docs/DEPLOYMENT_RUNBOOK.md`](docs/DEPLOYMENT_RUNBOOK.md)**
——這份文件假設你對這個 repo 完全沒有記憶，寫了完整現況、已知問題、和
每一步實際指令，不要憑印象或猜測跳過它。

## 目前狀態速覽（詳細見 runbook 最上面）

- **2026-09-14 完成（程式碼）：`#/lk` 自動授權（比照壽險版 insurance-exam-app
  的 lk-auto-authorization，但外幣版沒有電話/推薦人概念，改用「姓名+單位+員編」
  三欄辨識同一人）**。學員填姓名/單位/員編即可自動取得 60 天授權並直接登入，
  原本的授權碼輸入改為下方「改用授權碼登入」備用連結。範圍：
  `supabase/migrations/0007_lk_auto_auth_fields.sql`（`students` 新增
  `employee_id`）、`supabase/functions/auto-register-student/index.ts`（新
  Edge Function）、`lib/core/services/lk_auth_service.dart`
  （`autoRegister()`）、`lib/features/auth/lk_gate_page.dart`（雙模式表單）、
  `web/admin.html`（學員表格/Modal 加員編欄、學員與授權碼皆可刪除、統計加今日
  新增/即將到期/依單位分組）、新建 `web/admin-guide.html`、更新
  `web/student-guide.html`。`flutter analyze` 0 error、`flutter test` 42
  個測試全過（含新增 `test/features/auth/lk_gate_page_test.dart` 4 個）。
  **尚未部署**：migration 沒有 `supabase db push`、Edge Function 沒有
  `supabase functions deploy`、`web/` 底下的 html 沒有重新 build+部署到
  `gh-pages`，需要有 Supabase 專案存取權限的人接手，見下方「還沒做的事」。
- **2026-09-09 確認：ABCDE v3 題庫才是正式範圍，2025Q1 批次暫緩、不再繼續開發**。
  使用者另外上傳 `外幣題庫_ABCDE卷整理(含新增)v3.pdf`（跟 `scripts/extract/
  v3_pdf_update_2026-09-04.md` 記錄的來源檔逐位元組比對確認一致：317 筆原始列，
  A/B/C/D/E 各50+新增67），說明這份 ABCDE 卷本身就佔實際考試 90% 以上內容，
  應以此為主設計網站，其餘去掉。**查證後發現現有 118 題本來就 100% 來自這份
  ABCDE v3 檔案**，沒有別的來源混進去，所以「其餘」在資料庫裡對得上號的只有
  下面這條記的 715 題 2025Q1 批次。跟使用者確認後**決定不刪除**，715 題留在
  資料庫但維持 `reviewed=false`（考生看不到），**之後不再繼續投入**（不寫白話
  解析、不核複分類、不排進關卡），除非使用者之後另外要求重啟。目前及可預見
  未來，真實考生看到的內容 = 118 題 ABCDE v3 題庫，這才是網站的正式範圍。
- **2026-09-08 新增**：使用者提供 2025 Q1 版題庫 PDF（`C:\Sthou\Documents\Claude\Projects\Exam Master App\外幣\外幣2025第一季考題.pdf`，掃描檔無文字層，857 題），
  逐題視覺轉錄、去重（排除跟現有 118 題重複度≥85%、內部重複、時間快照統計題共
  142 題）、分類到現有 8 章後，715 題已 seed 進 Supabase，id 127-841。**這批全部
  `reviewed=false`**（新增的審核閘門，見下方），RLS policy 已改成
  `using (reviewed = true)`，真實考生完全看不到、無須改 Flutter 任何程式碼。
  分類信心不一：規則比對到法規名稱關鍵字的部分（486 題，分到 ch1-7）較可信；
  229 題落到 ch8（比對不到關鍵字的 fallback）需要人工複核分類是否正確。
  **這批新題完全沒有白話解析、`explanation` 也是空字串**，之後要一批一批
  `update reviewed = true` 才會讓考生看到，建議分批處理並在真正想開放某個批次
  前，先確認分類正確、有解析。轉錄/分類/去重的中間產物在
  `scripts/extract/output/`（已 gitignore，不進 git），`build_2025q1_seed.py`、
  `classify_2025q1.py` 這兩支腳本進了 git。
- 後台管理 `web/admin.html`（授權碼管理 + 學員管理，比照壽險版
  `insurance-exam-app/web/admin.html`）。管理員帳號 `admin@skl.com.tw` 已建立並
  實測登入成功，過程中修正 2 個 schema 落差（新增 `students` 表、
  `license_keys` 補 `notes` 欄位、`loadKeys()` 排序欄位改用 `expires_at`）。
  **還沒 build+部署**，細節見 runbook 最上面。
- **已正式上線**：https://shinkong-insurance.github.io/currency-insurance-exam/
  （GitHub repo：https://github.com/shinkong-insurance/currency-insurance-exam，
  `main` 放原始碼、`gh-pages` 放建置後的靜態網頁）
- **2026-09-09 完成：309 題題庫**（ABCDE v3 正式範圍 317 題，扣除 8 組確認
  逐字重複的題目）、8 章、18 關卡、4 張原文口訣卡已灌進 Supabase；301/309
  題白話解析已核准（7 題依專案慣例留白：ch2/ch3 沿用上一個 session 留白的
  5 題 + 這次 ch8 新留白的 2 題）。細節見 runbook 2026-09-09 條目。
- **Supabase 專案的 URL/API key 沒有存在這個 repo 或任何檔案裡**（刻意不
  存，避免 secret 外洩）——需要接手的人自己去 Supabase Dashboard 查，或問
  持有帳號的人要
- 測試授權碼：`SK-2026-TEST-0001`（無限次使用，2026-12-31 到期）

## 還沒做的事

- **`#/lk` 自動授權部署**（程式碼已完成，見上方 2026-09-14 條目）：
  1. `supabase db push`（或 Dashboard 手動執行）套用
     `0007_lk_auto_auth_fields.sql`
  2. `supabase functions deploy auto-register-student`（需先 `supabase login`
     + 專案存取權限；此 repo 內沒有存 Supabase URL/service role key，需另外
     設定環境變數 `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`——Edge Function
     執行環境會自動注入，不需要手動設定）
  3. `flutter build web --base-href /currency-insurance-exam/` 後把
     `build/web` 內容、連同 `web/admin.html`、`web/admin-guide.html`、
     `web/student-guide.html` 一併部署到 `gh-pages` 分支
  4. 部署後於正式站 `#/lk` 走一次完整流程（填姓名/單位/員編 → 確認直接登入
     → `admin.html` 能看到該筆新資料），並用 curl 測 Edge Function 的
     「新員編」「同姓名+單位+員編重複送出續權」「缺欄位」三種情境
- **✅ 2026-09-09 完成：ABCDE v3 題庫 317 題（實際 309 題，扣除 8 筆確認重複）
  全部可供考生練習**。147 題（ch5/6/7/8）白話解析已補完 145 題（2 題依專案
  慣例留白，見下方）、191 題新分類題目已 seed（`reviewed=true`）、18 個
  關卡已重建（題數加總 309，跟資料庫一致）、`flutter analyze` 0 error、
  `flutter test` 38 個測試全過。細節見
  [`docs/DEPLOYMENT_RUNBOOK.md`](docs/DEPLOYMENT_RUNBOOK.md) 2026-09-09
  條目、過程記錄見 [`docs/HANDOFF_TASK1_REMAINING.md`](docs/HANDOFF_TASK1_REMAINING.md)。
  **瀏覽器手動走查（登入→章節→關卡→作答→解析）尚待使用者自行確認**——這次
  執行環境的瀏覽器擴充套件帳號跟登入帳號不一致，無法用自動化工具操作，本機
  伺服器已跑在 `http://localhost:8765`（`flutter run -d web-server
  --web-port=8765`）。
  - id 978（110年7月新契約生命表）、id 980（被投資保險相關事業7日內陳報
    情事）這 2 題找不到明確依據（978 甚至跟簡報內容有出入：簡報說 110年7月
    是第六回、115年1月才改第七回，但題目給的正解是「第七回」），依專案慣例
    留白未寫解析。
- **抽取管線本身沒修，且這次又踩到一次坑**：`questions_with_chapter.json`
  仍然沒有修過抽取階段的去重邏輯，2026-09-09 這次重新跑 `seed_content.py`
  時，2026-09-03 已經從 Supabase 刪除的 8 筆「新增(E)卷逐字重複」題目
  （id 87,89,92,93,94,95,97,99）又被原封不動插回資料庫一次，已比照
  `supabase/migrations/0005_remove_duplicate_questions.sql` 的做法重新
  刪除、修復 `mnemonic_cards`「十權」卡的關聯。真正的根源是原始題庫 PDF 的
  「新增」(E) 卷逐字重複了 A/B/C 卷已出過的題目，要澈底修得回到抽取階段依
  「題目文字完全相同」做去重（照專案慣例：先寫測試再改 `scripts/extract`）。
  **下一個接手的人在重新跑 `seed_content.py` 之前，務必先確認這 8 個 id
  有沒有又跑回資料庫**。
- 10 張 AI 口訣候選卡的人工核准（`scripts/generate/ai_mnemonics_approval_checklist.md`）
- 4 句原文口訣裡有 2 句（週三日一、金三角）因來源題目沒被分類到章節而沒灌進資料庫
- id 122（新增-9，ch6）缺白話解析，課程簡報裡找不到依據，需對照正式法規全文
- 上線前應該把測試授權碼換成正式批次

## 開發慣例

- Python 抽取/種子腳本（`scripts/extract`、`scripts/generate`、`scripts/seed`）
  一律先寫測試再實作，每個腳本目錄下都有對應 `pytest`
- `scripts/extract/output/*.json` 是本機執行期產物，不進 git，需要時照
  `scripts/extract/v3_pdf_update_2026-09-04.md` 文末的指令重新產生
- Flutter 端改動後跑 `flutter analyze`（0 error）+ `flutter test`（42 tests）
- 部署到 GitHub Pages 記得帶 `--base-href /currency-insurance-exam/`，細節
  見 runbook 步驟 5
