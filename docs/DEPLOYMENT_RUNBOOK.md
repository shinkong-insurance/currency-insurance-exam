# 外幣保險資格測驗 App — 上線作業指南

給下一次接續作業時（不管是您自己動手，還是請 Claude 接續）使用。這份文件假設
執行者對這個 repo 完全沒有記憶，所以每一步都寫實際指令，不寫「請自行判斷」。

## 🐛 2026-09-08：考生實測回報「同樣的題目會重複」，查證屬實並修正

**根本原因**：原始題庫 PDF 的「新增」(E) 卷逐字重複了 A/B/C 卷已經出過的題目
（題幹、選項、答案、章節完全一致），2026-09-04 放寬 ch3 分類規則、題數從 114
灌到 126 題那次，抽取流程把這些重複內容當成全新題目各自建了 id，於是同一段
文字在 `questions` 表裡出現兩個不同 id。SQL 查證找到 **8 組、共 16 筆**：

| 章節 | 保留（A/B/C 卷原題） | 刪除（E 卷重複） |
|---|---|---|
| ch2 | id 1（A#3） | id 87（E#35） |
| ch2 | id 4（A#6） | id 89（E#37） |
| ch4 | id 10（A#16） | id 95（E#45） |
| ch4 | id 44（C#17） | id 97（E#47） |
| ch6 | id 9（A#12） | id 94（E#43） |
| ch6 | id 25（B#10） | id 93（E#42） |
| ch6 | id 40（C#9） | id 92（E#41） |
| ch7 | id 48（C#27） | id 99（E#50） |

這些重複 id 不會在同一個「關卡」裡出現兩次，但會分散在同一章節的不同關卡
（例如第6章第2關有 id 25、第6章第5關有它的重複題 id 93），考生照關卡順序
練習會遇到「這題剛剛不是寫過」；「模擬考」從全部題目隨機抽題，也有不低機率
同組重複題被一起抽到同一次考試。

**修正**（已套用到正式 Supabase 專案，`supabase/migrations/0005_remove_duplicate_questions.sql`）：
刪除前確認過 `key_favorites`/`key_wrong_answers` 都沒有任何學員資料引用這 8 個
要刪的 id，不會弄丟真實學員的收藏/錯題紀錄。動作：
1. `mnemonic_cards.related_question_ids` 有一張口訣卡（「十權」）連到 `[48,99]`，
   移除 99，只留原本的 48。
2. `levels.question_ids` 逐一移除這 8 個 id：第2章第3關、第2章第4關、第4章
   第2關、第6章第4關、第7章第2關各少 1 題（原本多半 7-8 題，變 6 題）；
   第6章第5關同時含 93、94 兩個要刪的 id，從 6 題變 4 題。
3. 刪除 `questions` 裡這 8 筆重複題本身。
4. 結果：題庫從 126 題變 **118 題**，白話解析核准數從 125 變 **117**（8 筆被
   刪的題目原本都在已核准的 125 題裡）。

**還沒修的地方**：這次只動了 Supabase 正式資料庫的資料，**沒有動
`scripts/extract`/`scripts/generate` 的抽取程式碼或
`scripts/seed/question_id_registry.json`**——如果之後從頭重新
`seed_content.py`（例如換一個新 Supabase 專案），這 8 筆重複題會原封不動再灌
回去一次。要澈底修，需要回到抽取階段依「題目文字完全相同」做去重（照專案
慣例：先寫測試再改程式）。這次的緊急修復是先讓正式站上的考生不再看到重複題，
根源修復留給下一次維護抽取管線時處理。

## 🎉🎉 2026-09-04：已經真的正式上線了，步驟 1-6 全部走完並公開部署成功

**正式網址：https://shinkong-insurance.github.io/currency-insurance-exam/**
（GitHub repo：https://github.com/shinkong-insurance/currency-insurance-exam，
`main` 分支放原始碼、`gh-pages` 分支放 build 好的靜態網頁，跟壽險版
`insurance-exam-app` 的部署模式一致）。

真的申請了 Supabase 專案（`ShinKong Currency Exam`，ap-southeast-2 / Sydney）、
套用 schema、灌資料、核准 125 題白話解析、build 網頁版並部署到 GitHub Pages、
建測試授權碼 `SK-2026-TEST-0001`，並在**正式網址上**完整走過一次：登入 →
首頁 → 章節列表 → 課程簡報翻頁 → 18關卡地圖 → 作答看解析 → 口訣卡，全部正常。
**目前這台機器上沒有留存這次用的 Supabase 專案 URL/key（沒有寫進任何檔案，
是當場問您取得的），如果要接續維護同一個專案，需要您重新提供。**

過程中發現並修正了 3 個新問題：

1. **RLS 被 Supabase 平台自動開啟**（已修正，見
   `supabase/migrations/0002_disable_rls_on_user_data_tables.sql`）：新申請
   的 Supabase 專案會對新建立的表**預設自動開啟 RLS**（這是 Supabase 平台
   這幾年的安全性變更，跟 `0001_init_schema.sql` 設計當時的預設行為不同）。
   `0001` 故意沒有幫 `license_keys`/`key_sessions`/`key_favorites`/
   `key_wrong_answers`/`level_progress`/`study_logs` 這 6 張表寫 RLS policy
   （理由見該檔案註解——沿用既有 `lk_auth_service.dart`/
   `cloud_sync_service.dart` 的信任模型，沒有 Supabase Auth session 可以
   驗證身分），但如果 RLS 被平台自動開啟又沒有任何 policy，效果等同全部
   擋掉，anon key 完全讀不到 `license_keys`，登入畫面會卡在「找不到此
   授權碼」。**套用 `0001` 之後，一定要接著套用 `0002`**，下面步驟 2 已經
   更新反映這件事。
2. **`build/web` 的 `<base href>` 沒有對到 GitHub Pages 的子路徑**：Flutter
   預設 build 出來的 `index.html` 用 `<base href="/">`，部署在網域根目錄
   沒問題，但 GitHub Pages 專案頁面是子路徑（`/currency-insurance-exam/`），
   資源全部抓錯路徑（404）。**build 網頁版時務必加
   `--base-href /currency-insurance-exam/`**（下面步驟 5 已更新）。
3. **兩個 App 共用同一個 GitHub Pages 網域，localStorage 互相污染**（已修正，
   見下方「已知落後項目」第 5 點）：`insurance-exam-app` 跟這個 App 都掛在
   `shinkong-insurance.github.io` 底下（只是路徑不同），瀏覽器 localStorage
   是照網域算、不分路徑，這個 App 從 scaffold 沿用的 key 名稱
   （`wrong_book`、`lk_logged_in`、`content_cache_questions` 等）原本跟
   壽險版完全一樣，會互相覆蓋/污染錯題本、收藏、登入狀態。已經全部加上
   `fx_` 前綴（`lib/core/database/shared_preferences_store.dart`、
   `lib/core/services/content_cache_store.dart`、
   `lib/core/services/lk_auth_service.dart`、`lib/main.dart`）並重新
   build+部署過，實測確認乾淨瀏覽器登入後資料正確、不再看到壽險版的殘留
   數字。**這個修正沒有處理壽險版那邊**（不在這次任務範圍內，`main` 分支
   上如果需要，那邊也應該加自己的前綴，但目前壽險版原本的 key 名稱維持
   不變，理論上不會反過來被這次的修正影響）。

## 🆕 2026-09-08：後台管理 `web/admin.html` 已建立（比照壽險版 `insurance-exam-app/web/admin.html`）

- 新增 `web/admin.html`：靜態單頁後台，直接用 `@supabase/supabase-js` v2 CDN
  連線本專案的 Supabase 專案（`ShinKong Currency Exam` / `omtbirjfkedwicfgvwdv`），
  URL 與 anon key 已內嵌在檔案裡（跟壽險版做法一致——這個 key 本來就是公開的
  anon key，且 `license_keys` 等表本來就對 anon 開放讀寫，見下方 RLS 說明）。
  兩個分頁：
  - 🔑 **授權碼管理**：對應現有 `license_keys` 表，新增/編輯/停用單筆授權碼、
    批次產生（1~200 組，格式 `SK-YYYY-XXXX-NNNN`，正則跟
    `lib/features/auth/lk_gate_page.dart` 完全一致）、查看單組授權碼的使用記錄
    （裝置數、收藏題數、錯題數，讀 `key_sessions`/`key_favorites`/`key_wrong_answers`）。
  - 👥 **學員管理**：對應**新建的** `students` 表（姓名/區部/單位/信箱/梯次/
    指定或自動分配授權碼/寄送 Email 通知），逐欄位對照壽險版 admin.html 的既有
    設計。**這張表是這次新增的**（`supabase/migrations/0003_add_students_table.sql`，
    已套用到正式 Supabase 專案），純後台記帳用途，Flutter app（`lib/`）完全不讀寫它。
- 登入畫面沿用壽險版模式：Supabase Auth email/password 登入，預設帶入
  `admin@shinkong.edu.tw`，但**這是獨立的 Supabase 專案，Auth 使用者不會跟壽險版
  共用**——目前這個專案裡還沒有任何 Auth 使用者，接手的人要先自己到
  [Supabase Dashboard → Authentication → Users](https://supabase.com/dashboard/project/omtbirjfkedwicfgvwdv/auth/users)
  建立一組帳密（例如同樣用 `admin@shinkong.edu.tw`），登入畫面才打得通。已用
  假密碼實測過，client 有正確連到這個專案並收到 Supabase 回應的
  `Invalid login credentials`（不是網路/CORS 錯誤），確認 URL/anon key 接線正確，
  只差真的建帳號這一步。
- **RLS 提醒（沿用既有、不是新風險）**：`students` 表比照 `license_keys` 等 6 張表
  明確關閉 RLS（見 `0003` 檔案註解），原因跟 0001/0002 一致——admin.html 用 anon
  key 直連，沒有 Supabase Auth session 可以驗證身分，加 RLS policy 只會擋掉自己。
  代價是任何拿得到這個 anon key 的人（例如直接看 `web/admin.html` 原始碼）都能
  略過登入畫面直接用瀏覽器 console 呼叫 `supabase.from('students')...` 讀寫資料，
  跟現有 `license_keys` 的既有風險屬於同一類，登入畫面是 UI 層級的門檔，不是資料
  層級的存取控制。
- **還沒做**：`flutter build web --base-href /currency-insurance-exam/ ...` 之後
  `build/web/admin.html` 才會是這個新版本，需要重新 build + 部署到 `gh-pages`
  分支（見下方步驟 5）才會反映到正式網址
  `https://shinkong-insurance.github.io/currency-insurance-exam/admin.html`。
- **管理員帳號已建立並實測登入成功**：`admin@skl.com.tw`（用這組取代原本
  admin.html 預設帶入的 `admin@shinkong.edu.tw`——這個 email 純粹是 Supabase
  Auth 的登入識別，跟真實網域無關，不需要收得到信，`web/admin.html` 只用
  `signInWithPassword`，沒有寄驗證信/忘記密碼寄信的流程）。用本機 `http-server`
  跑 `web/` 目錄實測整個後台，過程中發現並修正 2 個 schema 落差（壽險版
  `insurance-exam-app` 的 license_keys 表有這兩個欄位，外幣版當初建 `0001` 時
  漏了）：
  1. `loadKeys()` 原本 `.order('created_at', ...)`，但這個專案的 `license_keys`
     （見 `0001_init_schema.sql`）沒有 `created_at` 欄位，會直接載入失敗。
     已改成 `.order('expires_at', { ascending: false })`。
  2. 新增/編輯授權碼表單的「備註」欄位會送 `notes`，但 `license_keys` 沒有
     這個欄位，儲存會失敗。已新增
     `supabase/migrations/0004_add_notes_to_license_keys.sql`（`alter table
     license_keys add column notes text`，nullable，已套用到正式專案）。
  修正後完整測過：登入 → 學員管理（讀 `students`，目前 0 筆）→ 授權碼管理
  （讀到 `SK-2026-TEST-0001`，有效、0/∞、7 個裝置的使用記錄）→ 編輯授權碼
  存備註 → 都正常。

## 目前狀態（2026-09-04）

- 19 個開發任務 + 最終全分支審查 + 一輪修正都已完成並合併到 `master`（沒有
  殘留的 worktree 分支）。
- **114 題白話解析已對照課程簡報逐題核對過，找到並修正 2 個真實錯誤**
  （id 100、id 52，另精修 id 36 的說明），細節見
  `scripts/generate/plain_explanation_spotcheck_2026-09-04.md`。之後放寬
  ch3 分類規則多出的 12 題裡，也有 11 題比照同樣的核對方式補上了白話解析
  （只有 id 122 找不到法規依據還沒補，見 `v3_pdf_update_2026-09-04.md`
  文末），所以目前**共 125/126 題有白話解析**。
  **10 張 AI 口訣候選卡也已核對法規正確性**，2 張發現問題待您決定如何處理
  （#1 銀杏濃魚油漏了一類機構、#2 政庫軍的機關名稱已過時），細節見
  `scripts/generate/ai_mnemonics_approval_checklist.md`。這兩批內容仍然是
  **未核准**狀態（`plain_explanation_reviewed=false`、口訣卡未 insert），
  核對只是幫您把最該看的地方篩出來，最後核准動作還是要您親自按下去。
- **2026-09-04 换上新版題庫 PDF**（您提供的
  `外幣題庫_ABCDE卷整理(含新增)v3.pdf`，已複製到
  `~/Documents/外幣/` 並設為抽取管線預設來源）。過程中修掉一個抽取程式的
  bug（表頭偵測假設「每頁表格第0列都是表頭」在 v3 版不成立）。**好消息：
  已核對過的 114 題白話解析批次「內容」完全不受影響，不用重做**（題目 id
  一開始誤以為也不會位移，後來發現不是——見下面「同日也放寬了 ch3」那段
  之後的說明，已用穩定 id 對照表徹底解決）。
  v3 版本身帶了幾個真正的答案/內容修正（例如「業務單位自行查核→每半年、
  內部稽核單位查核→每年」這組先前互相矛盾的答案）。**原本有 5 題選項殘缺
  +3 題文字錯位需要人工處理，已於同日對照題庫固定格式與同題庫近似措辭的
  題目修正完畢**（`scripts/extract/fix_raw_text.py`，317 題現在全部結構化
  乾淨）。**同日也放寬了 ch3 的章節分類規則**（原本要求法規全名完全比對，
  漏收了幾題只寫規定主體、沒接完整法規名稱後半段的題目），全量比對過
  317 題確認 0 筆既有分類受影響。分類到章節的題目從一開始的 116 筆，
  經過這兩輪修正變成 **126 筆**（比 V1 版的 114 筆多出的 12 題，已補上
  白話解析——見下方「白話解析」段落，只有 1 題因找不到法規依據還沒補）。
  **這兩輪新增的題目插進了「新增」卷的中段**，讓原本 `seed_content.py`
  單純用 `enumerate()` 依序指派 question id 的做法整個不安全——已改用
  新增的 `scripts/seed/question_id_registry.json`（持久對照表，已 commit）
  + `scripts/seed/build_id_registry.py`，把 id 改成「第一次分類到時就
  固定下來，之後清單怎麼變都不會變」，確認原本 114 題的 id 完全沒變、
  新的 12 題依固定順序接在 115-126 號。因為目前還沒真的 seed 過 Supabase，
  這次修正沒有造成任何實際資料損壞。完整細節、以及口訣萃取意外多抓到
  2 句原文口訣的說明，見
  `scripts/extract/v3_pdf_update_2026-09-04.md`。`scripts/extract/output/*.json`
  是本機執行期產物（不進 git，重新產出時會自動套用上述修正），該報告文末
  附了重新產出的指令。
- **沒有真正的 Supabase 雲端專案**——全程用本機開發環境驗證，`lib/core/services/supabase_config.dart`
  目前是明確的佔位字串 `REPLACE_ME`，必須換成您自己申請的專案資訊。實際
  種子（seed）尚未執行過，所以上面提到的所有內容修正都還來得及在第一次
  seed 之前就整合進去，不涉及「已上線內容要改」的額外風險。
- **沒有正式部署網址**——Task 19 的部署步驟刻意保留給您決定（部署平台 / repo org）。
- **教材翻頁閱讀器沒有接上**（Task 16 產出的 263 張圖片目前沒有任何畫面在讀取，
  已知落後於 spec 原意，見下方「已知落後項目」）。
- **RLS 風險提醒**：目前 schema 對使用者資料表（license_keys 等）沒有 ownership
  層級的 RLS，任何持有 anon key 的人都能讀取全部授權碼、寫入任何學員的答題紀錄。
  這是延續壽險版既有設計，但正式上線前建議您重新評估這個風險是否可接受。

---

## 步驟 0：（已完成）分支已 merge 回 master

原本這裡是把開發用的 worktree 分支併回 `master` 的步驟，這件事已經做完
（目前 repo 已經直接在 `master` 上，沒有殘留的 worktree 或分支），這一步
不用再執行。以下步驟都是接續在 `master` 上進行。

（沒有 remote，所以沒有 push/PR 這個選項——如果之後想開 GitHub repo 放這個專案，
那是另一個獨立決定，見步驟 5。）

---

## 步驟 1：申請正式 Supabase 專案（需要您本人登入，Claude 無法代做）

1. 到 https://supabase.com/dashboard 用您的帳號登入（或註冊新帳號）。
2. 建立新專案，**不要**選到壽險版正在用的那個專案——這次要獨立一個新專案
   （spec 明確要求：不共用壽險的 Supabase 專案）。
3. 專案建好後，左側選單最下面 **Project Settings → API Keys**（新版 Supabase
   介面把這個獨立出來了，不一定叫「API」；也可以從專案首頁「Get connected」
   區塊點 **API Keys** 方塊直接進去），記下：
   - **Project URL**（首頁上就有，例如 `https://xxxxxxxx.supabase.co`）
   - **Publishable key**（`sb_publishable_...` 開頭——這是新版命名，等同舊版
     文件裡說的 `anon public` key，可以公開，用在下面 Flutter build 那步）
   - **Secret key**（`sb_secret_...` 開頭，預設遮住，要點眼睛圖示才會顯示——
     這是新版命名，等同舊版文件裡說的 `service_role` key，⚠️ 有完整資料庫
     寫入權限，只用在下面的種子腳本，不要放進 Flutter app 或任何前端程式碼）
   （如果您的專案介面還是舊版，會直接看到 `anon` / `service_role` 兩個 key，
   用法完全一樣，只是名字不同。）

## 步驟 2：套用 schema migration

**最簡單的做法（不需要另外申請 access token）：** 到 Supabase 左側選單點
**SQL Editor** → 開一個新查詢 → 把 `supabase/migrations/0001_init_schema.sql`
的內容整個貼進去 → 按 **Run**。**接著務必再貼一次
`supabase/migrations/0002_disable_rls_on_user_data_tables.sql` 的內容並
執行**（新專案會預設把 RLS 開在 `license_keys` 等表上，不套用 0002 的話
登入畫面會卡在「找不到此授權碼」，細節見本文件最上面「2026-09-04」那段）。

備案（需要 Supabase CLI 且已 `supabase login` 或有 access token）：

```bash
cd /Users/fortune/currency-insurance-exam   # merge 完之後 master 就有完整程式碼
export SUPABASE_ACCESS_TOKEN=<在 Supabase Dashboard → Account → Access Tokens 產生>
supabase link --project-ref <您的 project ref，網址列 xxxxxxxx 那一段>
supabase db push   # 依序套用 supabase/migrations/ 底下所有 migration，包含 0001 和 0002
```

## 步驟 3：灌資料（章節、題目、口訣、關卡）

```bash
export SUPABASE_URL=https://xxxxxxxx.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=<步驟1記下的 service_role key>

cd scripts/seed
pip install supabase   # 如果這台機器還沒裝過
python3 seed_content.py            # 灌 course/chapters/questions/mnemonic_cards(original)
python3 ../extract/run_build_levels.py   # 依剛灌進去的題目 id 切出 18 關（seed_levels.py 依賴這一步的輸出，漏了會直接 FileNotFoundError）
python3 seed_levels.py             # 灌 18 關卡資料
```

預期輸出類似（題數/口訣卡數字反映目前 `questions_with_chapter.json`/
`mnemonic_cards_original.json` 的內容，若您又重新產出過這兩個檔案，實際數字
可能不同，不代表跑錯）：
```
seeded 126 questions, 4 mnemonic cards
共產生 18 關
seeded 18 levels
```
（2 張口訣卡是 Task 5 抓到的原始口訣，AI 生成的 10 張候選卡不在這裡，見步驟 4b。）

## 步驟 4：白話解析 + AI 口訣卡的人工核准

### 4a. 白話解析（125/126 題，已有腳本可用）

**2026-09-04 更新：`scripts/generate/plain_explanation_spotcheck_2026-09-04.md`
點名的 21 題高風險清單 + 8 題中風險清單 + 1 題格式缺陷，都已對照
`/Users/fortune/Documents/外幣/外幣證照必勝寶典_授課簡報_20260805V1線上.pdf`
（課程簡報裡逐條列出的法規原文）逐題核對過，找到並修正了 2 個真實錯誤
（id 100 格式缺陷、id 52 內容錯誤），細節見該報告文末「後續處理紀錄」段落。
同日放寬 ch3 分類規則後多出的 12 題裡，也有 11 題比照同樣方式補上白話
解析並核對過（見 `scripts/extract/v3_pdf_update_2026-09-04.md`），只有
**id 122（新增-9，ch6）找不到法規依據，故意留白沒補**，需要您對照正式
法規全文（不是課程摘要簡報）確認後手動補上
`chapter_6_plain_explanations.json` 裡那一筆的 `plain_explanation`。**
剩下沒做的是：這次核對用的是課程簡報摘要，不是主管機關發布的正式法規全文，
理論上仍有極小機率簡報摘錄本身有誤；建議您（或可信任的人）還是抽個 5-10 題
親自看一眼 `scripts/generate/output/chapter_<N>_plain_explanations.json`
（N = 2,3,4,5,6,7）當最後一道保險，確認沒問題後（id 122 記得先補上或跳過
該筆，否則批次執行 --approve 時那筆的 `plain_explanation` 欄位還是空的），
逐章節執行：

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

## 步驟 5：build + 部署（**2026-09-04 已用這個流程正式上線過一次**）

```bash
flutter build web \
  --base-href /currency-insurance-exam/ \
  --dart-define=SUPABASE_URL=https://xxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<步驟1記下的 anon/publishable key>
```

**`--base-href /currency-insurance-exam/` 這個參數不能漏**——如果部署平台
不是 GitHub Pages 的子路徑（例如自訂網域，或整個部署在網域根目錄），要
改成對應的實際路徑；部署在網域根目錄的話可以整段拿掉（預設就是 `/`）。
漏了或值不對，網頁會卡在載入畫面，瀏覽器 console 會看到一堆資源 404
（詳見本文件最上面「2026-09-04」段落的問題 2）。

已決定用 **GitHub Pages**（比照壽險版 `insurance-exam-app` 的模式）：

```bash
# 建 repo（第一次才需要；已經建過的話跳過這步，直接 git remote add 接上）
gh repo create shinkong-insurance/currency-insurance-exam --public \
  --description "外幣保險資格測驗學習APP（網頁版）" --source=. --remote=origin

# push 原始碼（本地 master 對到遠端 main，跟壽險版一致）
git push -u origin master:main

# 把 build/web 的內容放到 gh-pages 分支（獨立 worktree操作，不動目前的工作目錄）
git worktree add --orphan -b gh-pages /tmp/currency-exam-ghpages   # 第一次建分支
# 之後每次重新部署，改用這個方式接上已存在的 gh-pages 分支：
#   git worktree add -b gh-pages-redeploy /tmp/currency-exam-ghpages origin/gh-pages
#   cd /tmp/currency-exam-ghpages && git rm -rf . >/dev/null
cp -r build/web/* /tmp/currency-exam-ghpages/
cd /tmp/currency-exam-ghpages
touch .nojekyll   # 停用 GitHub Pages 的 Jekyll 處理，避免它誤判某些檔案
git add -A
git commit -m "Deploy build/web to GitHub Pages"
git push origin HEAD:gh-pages
cd -
git worktree remove /tmp/currency-exam-ghpages --force

# 開啟 GitHub Pages（第一次才需要；推 gh-pages 分支後 GitHub 有時會自動偵測開啟，
# 用下面這行確認狀態，出現 409 "already enabled" 表示已經開好了，不用管）
gh api repos/shinkong-insurance/currency-insurance-exam/pages \
  -X POST -f "source[branch]=gh-pages" -f "source[path]=/"
```

部署後網址會是 `https://shinkong-insurance.github.io/currency-insurance-exam/`。
**GitHub Pages 的 CDN 更新有延遲**，push 完不會馬上生效，實測大約 1-2
分鐘；用瀏覽器測試時建議在網址後面加個隨便的查詢字串（例如 `?v=2`）強制
繞過瀏覽器快取，不然可能會一直看到部署前的舊版本。

如果不想用 GitHub Pages，其他選項：Vercel / Netlify / Firebase Hosting
都能直接吃 `build/web` 這個靜態資料夾，設定上更簡單，但跟壽險版不一致
（且這些平台通常部署在網域根目錄，`--base-href` 那段可以拿掉）。

## 步驟 6：發第一組測試授權碼（**2026-09-04 已建過一組，見下方**）

在 Supabase Table Editor 開 `license_keys` 表，新增一列（也可以用
`scripts/seed` 目錄下用同一組 SUPABASE_URL/SERVICE_ROLE_KEY 直接跑
Python 的 `supabase` client insert，不一定要手動點介面）：

| 欄位 | 範例值 |
|---|---|
| key_code | `SK-YYYY-XXXX-NNNN` 格式，例如 `SK-2026-TEST-0001`（⚠️ 注意：`lib/features/auth/lk_gate_page.dart` 有格式驗證，第二段必須是 4 位數字，不能像 `SK-TEST-0001-0001` 這樣把英文字母放在第二段，會被前端擋掉） |
| batch_name | `測試批次` |
| max_uses | `1`（或 `0` = 無限次） |
| expires_at | 例如 `2026-12-31T23:59:59+08:00` |
| is_active | `true` |

用這組授權碼在正式網址（或 build 出來本機測試）上走一次完整流程：登入 →
章節閱讀 → 課程簡報 → 練習 → 錯題本複習 → 口訣卡 → 18 關地圖 → 模擬測驗，
確認每個入口都正常。**2026-09-04 用 `SK-2026-TEST-0001` 這組在正式網址上
完整測過，全部正常。**

---

## 已知落後項目（上線前建議一併決定，但不阻擋上線）

1. ~~教材翻頁閱讀器沒接上~~ **2026-09-04 已解決**：新增 `GuideViewerPage`
   （`lib/features/guide/guide_viewer_page.dart`），從章節詳情頁的「課程簡報」
   按鈕進入，讀 `assets/json/guide_pages.json` 的頁碼範圍逐頁顯示
   `assets/images/guide/` 的 263 張圖，支援滑動翻頁+雙指縮放。已有 3 個
   widget test 覆蓋（`test/features/guide/`）。註：`assets/json/section_images.json`
   （單節一張示意圖，接在 `SectionReadingPage`）是另一個從未被 seed 過的
   獨立功能，跟這裡解決的翻頁簡報閱讀器是兩回事，如果之後要用還是需要另外
   產出資料並 seed。
2. **RLS 風險**（見上方「目前狀態」）——一旦真的接上正式 Supabase 專案，這個
   風險就是真的，不是假設性的。建議上線前重新確認是否接受。
3. 口訣卡文案（步驟 4b 那 10 張）用的是原始題庫掃描文字，包含頁碼引用跟斷行，
   核准前建議順手潤一下文字。
4. ~~`web/student-guide.html` 內容還是壽險版的~~ **已解決**：已改寫成外幣版
   實際章節/規則。
5. ~~兩個 App 共用 GitHub Pages 網域,localStorage 互相污染~~ **2026-09-04
   已解決**：`insurance-exam-app` 跟這個 App 都掛在
   `shinkong-insurance.github.io` 底下,瀏覽器 localStorage 是照網域算、
   不分路徑,原本沿用 scaffold 的 key 名稱完全一樣,會讓學員的錯題本、收藏、
   登入狀態在兩個 App 之間互相覆蓋。已把這個 App 用到的所有 key 加上 `fx_`
   前綴（`shared_preferences_store.dart`、`content_cache_store.dart`、
   `lk_auth_service.dart`、`main.dart`），實測確認修好。**注意：只改了這個
   App，沒有動壽險版**——如果之後壽險版也要處理類似風險，需要另外去那個
   repo 改。
