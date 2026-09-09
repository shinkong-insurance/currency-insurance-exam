# 外幣保險資格測驗 App

Flutter Web 考照練習 App（外幣保險資格測驗，沿用壽險版 `insurance-exam-app`
的架構：LK 授權碼登入、Supabase 內容、本機優先同步）。

**開始接手作業前，先讀 [`docs/DEPLOYMENT_RUNBOOK.md`](docs/DEPLOYMENT_RUNBOOK.md)**
——這份文件假設你對這個 repo 完全沒有記憶，寫了完整現況、已知問題、和
每一步實際指令，不要憑印象或猜測跳過它。

## 目前狀態速覽（詳細見 runbook 最上面）

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
- **118 題題庫**（2026-09-08 前是 126 題，考生實測回報「同樣的題目會重複」，
  查證後刪除 8 組真的逐字重複的題目，見下方「還沒做的事」）、8 章、18 關卡、
  2 張原文口訣卡已灌進 Supabase；125/126 題白話解析已核准（刪掉的 8 題都在
  已核准的那 125 題裡，實際剩 117 題有白話解析）
- **Supabase 專案的 URL/API key 沒有存在這個 repo 或任何檔案裡**（刻意不
  存，避免 secret 外洩）——需要接手的人自己去 Supabase Dashboard 查，或問
  持有帳號的人要
- 測試授權碼：`SK-2026-TEST-0001`（無限次使用，2026-12-31 到期）

## 還沒做的事

- **【下一個任務，2026-09-09 使用者拍板】讓 ABCDE v3 題庫 317 題全部都能給考生
  練習（目前只有 126→118 題上線，還有 191 題完全沒進網站）**。
  已查證：`run_classify_chapters.py` 對 v3 版 317 筆結構化題目（`structure
  cleanly: 317, needs manual review: 0`）分類，結果 **classified: 126,
  unclassified: 191**（跑法：`scripts/extract/run_segmentation.py` 指到
  這份 v3 PDF → `run_structure_questions.py` → `run_classify_chapters.py`）。
  印出的前 20 筆 unclassified 範例都是 A 卷題目，主題明顯屬於現有章節
  （例如 A-13/A-14 投資型保單連結標的物→ch6「投資型保險投資管理辦法」、
  A-20/A-21 申報結匯→ch5「外匯收支或交易申報辦法」、A-23/A-26/A-27/A-28/
  A-29/A-30/A-31/A-32/A-33/A-34/A-35 保險業國外投資→ch7「保險業辦理國外
  投資管理辦法」），只是題目本身沒有逐字引用法規全名，現有
  `classify_chapters.py` 的 regex 抓不到——跟 2025Q1 那批題目遇到的問題
  是同一種，當時是加一層主題關鍵字 fallback（`classify_2025q1.py` 的
  `_FALLBACK_PATTERNS`）解決的，這次應該可以直接沿用/擴充同一招。
  完整任務範圍：
  1. 擴充分類規則（fallback 關鍵字），把 191 題盡量分進現有 8 章
     （8「人身保險基本概念及其他」本來就是真正的通識/其他類，A-1、A-2
     這種沒有明確法規主題的題目本來就該落在這裡，不是 bug）。
  2. 對新分類出的題目補上白話解析（`explanation` 欄位），寫法比照既有
     `plain_explanation_batch.md` 的慣例；沒有把握的（像 id 122 新增-9
     那樣）依專案慣例寧可留白也不要瞎猜。
  3. 重新指派 id 時務必用 `scripts/seed/question_id_registry.json` +
     `build_id_registry.py` 的「首次分類到就固定住」邏輯，不要用
     `enumerate()`，否則既有 118 題（id 1-126 扣掉刪除的 8 個）的 id
     可能被打亂（這正是 v3 更新報告裡踩過的坑，見上面 `v3_pdf_update_
     2026-09-04.md`）。
  4. 新分出的題目要排進 18 個關卡（`levels.question_ids`）才會真的出現在
     考生的關卡練習流程裡，不是灌進 `questions` 表就結束。
  5. Seed 時直接 `reviewed=true`（這批是 ABCDE v3 正式範圍內的題目，不是
     像 2025Q1 那樣需要審核閘門擋著的補充內容）。
  6. 走完後跑一次 `flutter analyze`（0 error）+ `flutter test`，並在瀏覽器
     完整走一次登入→章節→關卡→作答→解析確認新題目看得到、答得了、有解析。
  **注意（這台 Windows 機器上剛踩到的新坑）**：Python 讀寫這些腳本的
  UTF-8 JSON/PDF 檔案時，Windows 預設主控台編碼是 cp950，裸用
  `Path.read_text()` / `open()` 不指定 `encoding='utf-8'` 會丟
  `UnicodeDecodeError`。跑這些腳本前先 `export PYTHONUTF8=1`（或在
  Python 腳本裡都明確帶 `encoding='utf-8'`），比較保險是把
  `PYTHONUTF8=1` 設成這台機器上跑 `scripts/extract`/`scripts/generate`/
  `scripts/seed` 的固定前綴。
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
