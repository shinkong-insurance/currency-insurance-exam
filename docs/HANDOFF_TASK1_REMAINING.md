# Task 1 交接：把 ABCDE v3 題庫剩下的題目補完解析、排關卡、上線

**寫給另一個 Claude terminal session（不同帳號）接手用。假設你對這個 repo
完全沒有記憶。先讀 [`CLAUDE.md`](../CLAUDE.md) 建立整體背景，再回來看這份。**

## ⚠️ 先看這個：已修好的一個嚴重 id 衝突 bug

上一個 session 原本用 `scripts/seed/build_id_registry.py` 幫 191 題新分類出來
的 ABCDE 題目指派 id，邏輯是「接在 registry 檔案自己記錄的最大 id（126）後面」
→ 算出 id 127-317。**這是錯的**：Supabase `questions` 表裡 id 127-841 這個
範圍，早就被另一批完全不相關的資料（2025Q1 補充題庫，715 題，`exam_set
='2025Q1'`, `reviewed=false`）佔用了——那批用的是另一支腳本
（`build_2025q1_seed.py`）自己的 id 邏輯，沒有登記進 `question_id_registry.
json`，所以 registry 完全不知道 127-841 已經有人用了。如果照原邏輯把 191 題
ABCDE 內容 seed 進去，會直接用 id 主鍵覆蓋掉 2025Q1 那 191 筆資料（`upsert`
對同一個 id 做 `ON CONFLICT DO UPDATE`），把它們的內容整筆換掉、永久遺失。

**已經修正**（這個 session 已完成，不用重做）：
- `scripts/seed/question_id_registry.json`：191 題新題目改指派 id
  **842-1032**（Supabase 目前實際 `max(id)=841`，842 起才是真正沒人用的
  範圍）。原本 1-126 的既有題目 id 完全沒動。
- `scripts/extract/output/all_317_with_id.json`、`classified_191_v4.json`：
  已用修正後的 registry 重新產生，id 欄位現在是對的。
- `scripts/generate/output/chapter_1_plain_explanations.json`（3 筆）、
  `chapter_2_plain_explanations.json`（新增的 5 筆）、
  `chapter_3_plain_explanations.json`（新增的 31 筆）：id 欄位已同步改成
  842-1032 範圍內的正確值（用 `(exam_set, question_no)` 去 registry 重新查
  出正確 id，不是位置猜測）。

**接手時務必：**
- 之後任何時候都不要再手動跑 `python3 build_id_registry.py`
  或自己重寫 `next_id = max(...) + 1` 這種邏輯去「修正」id——現在的
  `question_id_registry.json` 已經是正確、最終的對照表，191 題新題目
  的 id 固定是 842-1032，直接查表用即可。
- 如果之後 `seed_content.py` 要重新指派 id（例如又分類出更多新題），
  一定要先跟 Supabase 目前的 `max(id)` 對過，不能只信任 registry 檔案
  自己的最大值——這正是這次踩到的坑。

## 目前進度（哪些做完了、哪些還沒）

191 題新分類題目依章節分佈：ch1=3、ch2=7、ch3=34、ch5=13、ch6=28、ch7=56、
ch8=50。白話解析（`plain_explanation`）進度：

| 章節 | 題數 | 狀態 |
|---|---|---|
| ch1 | 3 | ✅ 已完成（3/3 都寫了） |
| ch2 | 7 | ✅ 已完成（5 題寫了解析，2 題原始解析不足以驗證具體數字，依專案慣例刻意留白——**留白的做法是「完全不寫進 JSON 檔案」，不是寫一筆 `plain_explanation:""`**，見下方檔案結構） |
| ch3 | 34 | ✅ 已完成（31 題寫了解析，3 題因選項結構太模糊/查無依據留白） |
| ch5 | 13 | ❌ **還沒做** |
| ch6 | 28 | ❌ **還沒做** |
| ch7 | 56 | ❌ **還沒做** |
| ch8 | 50 | ❌ **還沒做**（`chapter_8_plain_explanations.json` 這個檔案還不存在，要新建） |

**你要做的：完成 ch5、ch6、ch7、ch8 這 147 題的白話解析。**

## 參考檔案（都在本機硬碟上，同一台 Mac 的任何 terminal 都讀得到）

- `scripts/extract/output/all_317_with_id.json` — 317 題全部題目，含正確
  `id`、`chapter_id`、`question`、`options`、`answer`、`explanation`
  （原始簡短提示/口訣）、`exam_set`、`question_no`。**這是你的主要資料源**。
- `scripts/extract/output/classified_191_v4.json` — 上面檔案裡 `id>126`
  的 191 筆子集（就是這次新分類出來的題目），已附 `auto_classified` 欄位
  （True=規則比對到、False=落到 ch8 catch-all）。
- `scripts/extract/output/slide_full_text.txt` — 課程簡報
  `外幣證照必勝寶典_授課簡報_20260805V1線上.pdf` 全文（263 頁純文字），
  `explanation` 欄位是空字串時，用這個檔案 `grep` 查證用詞是否存在。
- `scripts/generate/output/chapter_1/2/3_plain_explanations.json` — 已完成
  的三章範例，照它們的寫法跟語氣延續 ch5/6/7/8。

## 寫白話解析的方法（照既有慣例，不要偏離）

對 `all_317_with_id.json` 裡 `chapter_id==N and id>126` 的每一題：

1. **優先依據該題的 `explanation` 欄位**（原始簡短提示，例如「外投年轉臺」
   「1)、2)央行核准...」這種）——把它展開成完整的白話推理句子，說明「為什麼
   這個答案是對的／為什麼其他選項不對」。
2. `explanation` 是空字串時，去 `slide_full_text.txt` 裡 `grep` 題目關鍵詞
   （法規名稱、具體數字、專有名詞），找到明確依據才寫；範例：
   ```bash
   grep -n -B3 -A6 "關鍵字" scripts/extract/output/slide_full_text.txt
   ```
3. **找不到依據、或選項邏輯本身有歧義看不出唯一解讀（例如題幹裡出現「以上
   皆可」這種巢狀結構、多選組合對不齊）時，寧可留白也不要瞎猜**——留白的
   做法是**這一題完全不要寫進輸出的 JSON 檔案**（不是寫一筆
   `"plain_explanation": ""`），這樣之後這題在 Supabase 裡
   `plain_explanation_reviewed` 會維持 `false`（預設值），app 就不會顯示
   半吊子的解析，但題目本身、選項、正解一樣看得到、答得了。
4. 語氣、長度比照 `chapter_1/2/3_plain_explanations.json` 裡已經寫好的
   句子（繁體中文、口語化但精確，通常 2-4 句，直接點出關鍵規則/數字/易混淆
   點，不要客套話）。

### 輸出格式（每章一個檔案）

寫到 `scripts/generate/output/chapter_N_plain_explanations.json`（ch8 要
新建）。是否已有既有內容（ch5/6/7 這三個檔案目前是**舊版、id 對不上**的
殘留檔——內容是很久以前另一批題目的解析，跟這次的 191 題完全無關，**必須
先確認裡面的 id 是否落在 1-126 範圍內再決定要不要保留**，新加的 191 題內容
用 `.extend()` 接上去，不要覆蓋掉舊的）：

```python
import json
new_entries = [
    {"exam_set": "A", "question_no": 47, "id": 843,
     "original_explanation": "...(填 all_317_with_id.json 裡的 explanation 欄位原文)...",
     "plain_explanation": "...(你寫的白話解析)..."},
    # ...
]
path = "scripts/generate/output/chapter_5_plain_explanations.json"
try:
    existing = json.load(open(path))
except FileNotFoundError:
    existing = []
# 先過濾掉任何 id 落在 842-1032 範圍內的舊殘留（如果有的話，代表是上一輪
# 用錯誤 id 寫的殘留資料，要丟棄重寫），避免同一題出現兩筆衝突的解析
existing = [e for e in existing if not (842 <= e["id"] <= 1032)]
existing.extend(new_entries)
existing.sort(key=lambda e: e["id"])
json.dump(existing, open(path, "w"), ensure_ascii=False, indent=2)
```

**先跑一次確認 ch5/6/7 舊檔案內容是不是這次要的東西**：
```bash
python3 -c "
import json
for n in (5,6,7):
    d = json.load(open(f'scripts/generate/output/chapter_{n}_plain_explanations.json'))
    ids = sorted(e['id'] for e in d)
    print(n, len(d), 'id range', ids[0], '-', ids[-1])
"
```
如果印出來的 id 都 ≤126，代表是既有、無關的舊資料，**不要動它**，你只需要
把 842-1032 範圍的 191 題新解析 `extend` 進去就好。

## 全部 147 題解析寫完之後，剩下的步驟（照順序）

1. **重新跑分類測試**（確認沒有動到 `classify_chapters.py` 本身邏輯，純粹
   確認環境正常）：
   ```bash
   cd scripts/extract && python3 -m pytest -q
   ```

2. **Seed 191 題新題目本體到 Supabase**（`questions` 表的
   question/options/answer/explanation/chapter_id 這些欄位，不含
   `plain_explanation`）：
   ```bash
   export SUPABASE_URL=...           # 跟使用者要，或用你自己帳號的 Supabase MCP
   export SUPABASE_SERVICE_ROLE_KEY=...
   cd scripts/seed && python3 seed_content.py
   ```
   這支腳本會把 `questions_with_chapter.json`（317 筆全部）整批 upsert，
   `to_question_row()` 沒有帶 `reviewed` 欄位——**這是刻意的、不用另外改**：
   - 對 842-1032 這 191 個全新 id 來說是 INSERT，資料庫欄位預設值
     `reviewed DEFAULT true`，所以會自動變成 `reviewed=true`（可上線），
     符合這次任務要求，**不需要另外下 UPDATE**。
   - 對既有 1-126 的題目來說是 UPDATE（衝突鍵是 id），沒帶的欄位
     PostgREST 不會覆蓋，既有的 `reviewed` 值原封不動，安全。
   跑完之後務必用 SQL 驗證一下（Supabase MCP 的 `execute_sql` 或
   Dashboard）：
   ```sql
   select count(*) from questions where id between 842 and 1032 and reviewed=true;
   -- 應該是 191
   select count(*) from questions where exam_set='2025Q1';
   -- 應該還是 715，內容沒被動到（拿 id=127 跟 id=300 抽查 exam_set 是否仍是 '2025Q1'）
   ```

3. **重建 18 個關卡**（讓新題目真的排進考生會走到的關卡流程，不是只在
   `questions` 表躺著）：
   ```bash
   cd scripts/extract && python3 run_build_levels.py
   cd ../seed && python3 seed_levels.py
   ```
   `run_build_levels.py` 讀的是 `seed_content.py` 上一步寫出的
   `scripts/extract/output/questions_seeded.json`（含最新、正確的 id），
   所以第 2 步一定要先做。跑完看終端機印出的「共產生 18 關」和每關題數，
   跟 `flutter` 前端顯示的關卡數對一下。

4. **寫入白話解析並核可**（每個新出現解析的章節都要跑，ch1/2/3/5/6/7/8）：
   ```bash
   cd scripts/generate
   for n in 1 2 3 5 6 7 8; do
     python3 update_plain_explanations.py $n --approve
   done
   ```
   `--approve` 會同時把 `plain_explanation_reviewed` 設成 `true`（沒有這個
   flag 的話文字寫進去了但 app 不會顯示）。**在下這個 flag 前，至少抽查
   20% 的內容**（每章隨機挑幾題，人工核對你寫的白話解析跟正確答案邏輯一致、
   沒有幻覺捏造規則），這是專案既有的人工把關慣例。

5. **驗證**：
   ```bash
   cd /Users/fortune/currency-insurance-exam
   flutter analyze   # 預期 0 error
   flutter test      # 預期全過（原本 38 個 test）
   ```
   然後啟動本機開發伺服器，瀏覽器走一次：登入（測試授權碼
   `SK-2026-TEST-0001`）→ 選章節 → 選新關卡 → 作答 → 看解析，確認新題目
   看得到、答得了、有白話解析顯示。

6. **更新文件**：把 `CLAUDE.md`「還沒做的事」裡第一項的任務描述改成完成
   狀態（317 題全上線），順便把這份 handoff 文件的內容摘要記一筆進
   `docs/DEPLOYMENT_RUNBOOK.md`（照它既有的時間戳記格式）。

7. **git commit**（先 `git status` 看清楚改了哪些檔案再 add，訊息結尾帶
   `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`）。**不要
   `git push`**，除非使用者明確要求——兩邊 terminal 可能同時在改
   本機檔案，push 前跟使用者確認一次現在是哪邊在做最後收尾比較保險。

## Supabase 存取

這個專案的 Supabase URL/API key 刻意不存在 repo 裡。如果你這個帳號已經連了
Supabase MCP（工具名稱類似 `mcp__<hash>__execute_sql`），可以直接用 MCP 查
`list_projects` 找到這個專案（名稱「ShinKong Currency Exam」）。如果沒有連，
跟使用者要 `SUPABASE_URL` 跟 `SUPABASE_SERVICE_ROLE_KEY`（Service Role
key，不是 anon key，因為要繞過 RLS 寫入）。
