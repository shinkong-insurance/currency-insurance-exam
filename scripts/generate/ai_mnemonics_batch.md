# Task 18 — AI-Generated Mnemonic Candidates (`source: ai_generated`, `approved: false`)

**Status: NOT APPROVED. Nothing in this document has been written to Supabase.** Every
card below is a proposal only. A human reviewer must check each one for regulatory
accuracy before any `mnemonic_cards` row is inserted with `approved: true`. Until then
the RLS policy from Task 2 keeps `approved: false` rows invisible in the app regardless.

This is a companion to Task 5's `scripts/extract/output/mnemonic_cards_original.json`
(4 mnemonics the *original* question-bank author had explicitly labeled "口訣", extracted
verbatim). This task instead proposes *new* mnemonic phrases for numeric/list-heavy rules
that the author did **not** explicitly tag as "口訣".

## Scope

Candidate search was restricted to the 114 questions in
`scripts/extract/output/questions_with_chapter.json` (the same set already seeded to
Supabase, per `scripts/extract/output/questions_seeded.json`, which supplies the real
`id` values used below as `related_question_ids`). The other ~192 questions in the full
306-question corpus were **not** considered, since they have no real Supabase question id
for a card to reference.

## Method

1. Loaded the 114 chapter-classified questions and the 4 existing mnemonics; built a set
   of `(exam_set, question_no)` pairs already covered by Task 5's output so as not to
   duplicate coverage. (Covered set: A-47, B-47, E-16, E-17, C-26, C-27, E-50, D-33.)
2. Dumped all 114 `question` + `options` + `explanation` triples and manually read every
   one (not just grepped), looking for: percentage caps, day/workday/month/year counts,
   dates, and enumerated A/B/C/D-style lists of substantive regulatory facts — the same
   character of content as the 4 existing examples (三 numbers → 金三角; a % threshold →
   十權).
3. Within that pool, two sub-categories of candidate emerged:
   - **(a) Author already half-compressed it.** Several explanations contain the
     author's own informal shorthand or wordplay that Task 5's search missed because it
     didn't literally contain the string "口訣" (e.g. `銀行業→銀杏濃魚油`,
     `金證投(金枕頭)`, `國外投資風險監控管理措施→構政制`, `→分析、執行、檢討`,
     `→關閉、停止或限制、命令、處置`). These are the lowest-risk candidates in this
     batch: the phrase (or its direct components) already comes from the original
     author, not from me — I only formalized it into a mnemonic-card shape.
   - **(b) Genuinely new compression.** A handful of single, clean, verifiable
     numeric/day-count facts stated directly in the question stem, with tempting
     numeric distractors in the options, where no author shorthand existed at all. For
     these I invented a short 2–4 character phrase in the same "number + abbreviated
     concept" style as `十權`/`金三角`/`總是` (e.g. `十五工` for "15 workdays",
     `五十報` for "NT$500,000 → 申報").
4. Rejected outright:
   - Any question whose `explanation` was **empty** (mostly the `新增-*` exam-set
     entries), even if the question text contained an attractive-looking number or
     list — e.g. E-13 (結購/結售限額), E-23 (非法買賣外匯刑期), 新增-41 (BB+ 2%
     threshold), 新增-44/45/50/59. Without the author's own confirmed-correct answer
     reasoning I have no independent way to verify which option is actually right, so I
     will not invent a mnemonic that could reinforce a wrong answer.
   - D-19 (`破產→發行/經理(收行理)`): the author's own shorthand text looks corrupted
     or OCR-garbled (`收行理` doesn't cleanly map onto any of 發行/保證/保管/經理) and
     I could not confidently reconstruct what it was supposed to say. Skipped rather
     than guess.
   - Bare statute article numbers (e.g. "第9條", "第15-1條") — memorizing an article
     number in isolation doesn't match the character of the existing examples, which
     are about substantive caps/thresholds/lists, not citation numbers.
   - Anything already covered by Task 5's 4 mnemonics.
5. For every surviving candidate, cross-checked the question's `answer` index against
   the full `options` array to confirm exactly which lettered items are correct, then
   wrote the phrase/meaning to match only the confirmed-correct items (see "Self-review"
   below for the specific checks performed per card).

## Proposed candidates (10)

### 1. `銀杏濃魚油`
- **Covers:** A-19 (id 13), chapter 5
- **Source of phrase:** author's own explanation text, reused verbatim (not invented)
- **Meaning:** 「外匯收支或交易申報辦法」所稱「銀行業」，指經中央銀行許可辦理外匯業務之：
  銀行、信用合作社、農會信用部、漁會信用部、中華郵政股份有限公司（全部五者皆屬銀行業，
  正確答案為 A-19 選項 ＡＢＣＤＥ）。諧音對應：銀（銀行）、杏（諧音「信」→信用合作社）、
  濃（諧音「農」→農會信用部）、魚（諧音「漁」→漁會信用部）、油（諧音「郵」→中華郵政）。

### 2. `政庫軍`
- **Covers:** A-16 (id 10), E-45 (id 95), chapter 4
- **Source of phrase:** my compression of the author's own keyword hint
  (`政府、國庫、軍政機關`) into a 3-character acronym
- **Meaning:** 「管理外匯條例」第4條：國庫對外債務之保證、管理及其清償之稽催，由「管理
  外匯之行政主管機關」（財政部）辦理。判斷關鍵字：題目出現「政府」「國庫」「軍政機關」
  等字眼時，答案指向行政主管機關（財政部），而非中央銀行。

### 3. `雙外`
- **Covers:** B-16 (id 27), C-16 (id 43), E-46 (id 96), chapter 4
- **Source of phrase:** my compression of the author's own keyword hint
  (`外國、外匯`) into a 2-character acronym
- **Meaning:** 「管理外匯條例」第5條：外匯調度及收支計畫之擬訂、指定銀行辦理外匯業務之
  督導、調節外匯供需以維持有秩序之外匯市場，均由「管理外匯業務機關」（中央銀行）辦理。
  判斷關鍵字：題目出現「外國」「外匯」等業務性字眼（兩個「外」字）時，答案指向業務機關
  （央行），而非行政主管機關（財政部）。與 #2 是一組對照記憶（政庫軍→財政部 vs.
  雙外→央行）。

### 4. `金枕頭`
- **Covers:** D-11 (id 60), chapter 6
- **Source of phrase:** author's own shorthand (`金證投`) and parenthetical nickname
  (`金枕頭`), reused as-is
- **Meaning:** 「投資型保險投資管理辦法」第5條第1項第1款：保險人運用與管理專設帳簿資產，
  應指派具有「金融」「證券」「其他投資」業務經驗之專業人員（不含「保險」，正確答案為
  D-11 選項 ＡＢＤ）。原解析縮寫「金證投」，戲稱其諧音近似水果「金枕頭」（金枕頭榴槤）
  以利記憶。

### 5. `構政制`
- **Covers:** D-42 (id 76), chapter 7
- **Source of phrase:** author's own explanation text, reused verbatim
- **Meaning:** 「保險業辦理國外投資管理辦法」第15條：保險業訂定國外投資風險監控管理
  措施，應包括有效執行之風險管理「架構」「政策」「制度」（不含「程序」，正確答案為
  D-42 選項 ＡＢＣ）。

### 6. `分執討`
- **Covers:** D-41 (id 75), chapter 7
- **Source of phrase:** my 3-character compression of the author's own explanation
  (`分析、執行、檢討`)
- **Meaning:** 「保險業辦理國外投資管理辦法」第15條第2項：國外投資相關交易處理程序應
  包括「（書面）分析報告之製作」「交付執行之紀錄」「檢討報告之提交」（不含「制定整體性
  投資政策」，正確答案為 D-41 選項 BCD），相關資料應至少保存五年。

### 7. `關停命處`
- **Covers:** B-17 (id 28), E-47 (id 97), chapter 4
- **Source of phrase:** my 4-character compression of the author's own explanation
  (`關閉、停止或限制、命令、處置`)
- **Meaning:** 「管理外匯條例」第19-1條：國內外經濟失調，有危及本國經濟穩定之虞，或本國
  國際收支發生嚴重逆差時，行政院得決定並公告於一定期間內，採取「關」閉外匯市場、
  「停」止或限制全部或部分外匯之支付、「命」令將全部或部分外匯結售或存入指定銀行、或為
  其他必要之「處」置。

### 8. `十五工`
- **Covers:** C-8 (id 39), 新增-46 (id 111), chapter 6
- **Source of phrase:** genuinely new — no author shorthand existed for this fact
- **Meaning:** 「投資型保險投資管理辦法」第6條第2項：專設帳簿保管機構有變更者，應於
  變更後「十五個工作日內」向主管機關申報。C-8 的題幹本身即明文寫出「十五個工作日內」；
  新增-46 以此作為選擇題的正確答案（對照選項含 2個月/1週/1個月等干擾項），故雙重驗證。

### 9. `年一時`
- **Covers:** E-5 (id 77), E-6 (id 78), chapter 3
- **Source of phrase:** genuinely new — direct compression of the confirmed numeric fact
- **Meaning:** 人身保險業辦理以外幣收付之非投資型人身保險業務，每年應為銷售該等商品之
  業務員舉辦至少「1小時」之匯率風險及外匯相關法規在職教育訓練課程（E-6 選項含
  6/1/3/2小時等干擾項，正確為1小時）。年-每年，一-1，時-小時。

### 10. `五十報`
- **Covers:** C-18 (id 45), D-23 (id 70), chapter 5
- **Source of phrase:** genuinely new — direct compression of the confirmed numeric fact
- **Meaning:** 中華民國境內「新臺幣五十萬元」以上等值外匯收支或交易之資金所有者或
  需求者，應依「外匯收支或交易申報辦法」申報（C-18 選項含30萬/150萬/100萬等干擾項，
  正確為50萬）。五十-新臺幣50萬元門檻，報-申報。**注意**：此處「五十」指新臺幣50萬元
  之金額門檻，並非「50」這個數字本身或年齡意義上的「半百」，人工覆核時請特別確認學生
  不會誤解為其他單位或誤與其他章節的百分比／年數口訣混淆。

## Self-review (accuracy re-verification)

For every candidate above I re-pulled the source question's `answer` index against its
full `options` array (not just the `explanation` string) to confirm which lettered items
are actually correct, since several of these questions have trap options (e.g. B-4's
"經金管會許可" vs the correct "中央銀行許可" agency-name trap). Specific checks:

- **#1** A-19 `answer=1` → `options[0]` = "ＡＢＣＤＥ" — confirms all 5 entities listed
  belong to 銀行業; phrase is a straight restatement, no compression risk.
- **#2/#3** A-16/E-45 `answer=2` → "管理外匯之行政主管機關"; B-16 `answer=3` →
  "管理外匯業務機關"; C-16 `answer=3` → "掌理外匯業務機關"; E-46 `answer=4` →
  "管理外匯業務機關". Confirms the two-way keyword split is consistent across all 5
  question instances, not a one-off.
- **#4** D-11 `answer=2` → `options[1]` = "ABD" (金融/證券/其他投資), confirming 保險
  (C) is excluded — matches "金證投" exactly.
- **#5** D-42 `answer=3` → `options[2]` = "ABC" (政策/架構/制度), confirming 程序 (D) is
  excluded — matches "構政制" exactly.
- **#6** D-41 `answer=2` → `options[1]` = "BCD" (分析/執行/檢討), confirming 整體性投資
  政策 (A) is excluded — matches "分執討" exactly.
- **#7** B-17 `answer=1` → `options[0]` = "ABC" (all 3 listed actions correct in that
  question's shorter stem); E-47 `answer=3` → `options[2]` = "ABC" (國內經濟失調/國外
  經濟失調/本國逆差all correct, 新台幣匯率大幅波動 excluded) — confirms both trigger
  conditions and both trigger conditions, consistent with the four-action phrase.
- **#8** C-8's "十五個工作日內" is asserted directly in the question stem (not an
  option to verify), and 新增-46 independently confirms it as the graded-correct option
  (`answer=4` → `options[3]` = "15個工作日內") against 3 numeric distractors.
- **#9** E-5 `answer=3` → `options[2]` = "匯率風險及外匯相關法規" (confirms *content* of
  training); E-6 `answer=2` → `options[1]` = "1小時" (confirms *duration*) — the two
  questions together confirm both halves of the fact independently.
- **#10** C-18 `answer=1` → `options[0]` = "新台幣五十萬元"; D-23 `answer=2` →
  `options[1]` = "外匯收支或交易申報辦法" — the two questions confirm both the amount and
  the governing regulation independently.

No accuracy problems were found in this self-review pass; all 10 phrases match their
confirmed-correct option sets. This does **not** substitute for the required human
regulatory-accuracy review — I have no authority to mark any of these `approved`.

## Review table (all unchecked — human sign-off required before `approved: true`)

| # | Phrase | Covers (question ids) | Chapter | Regulatory accuracy verified by human? | Mnemonic clear & memorable? | Approved (`approved=true`)? |
|---|--------|------------------------|---------|:---:|:---:|:---:|
| 1 | 銀杏濃魚油 | 13 (A-19) | 5 | [ ] | [ ] | [ ] |
| 2 | 政庫軍 | 10, 95 (A-16, E-45) | 4 | [ ] | [ ] | [ ] |
| 3 | 雙外 | 27, 43, 96 (B-16, C-16, E-46) | 4 | [ ] | [ ] | [ ] |
| 4 | 金枕頭 | 60 (D-11) | 6 | [ ] | [ ] | [ ] |
| 5 | 構政制 | 76 (D-42) | 7 | [ ] | [ ] | [ ] |
| 6 | 分執討 | 75 (D-41) | 7 | [ ] | [ ] | [ ] |
| 7 | 關停命處 | 28, 97 (B-17, E-47) | 4 | [ ] | [ ] | [ ] |
| 8 | 十五工 | 39, 111 (C-8, 新增-46) | 6 | [ ] | [ ] | [ ] |
| 9 | 年一時 | 77, 78 (E-5, E-6) | 3 | [ ] | [ ] | [ ] |
| 10 | 五十報 | 45, 70 (C-18, D-23) | 5 | [ ] | [ ] | [ ] |

## Rejected candidates (for transparency — not proposed)

| Question(s) | Numeric/list content | Why rejected |
|---|---|---|
| D-19 | 破產→發行/經理(收行理) | Author's own shorthand text looks corrupted/OCR-garbled; could not confidently reconstruct the intended mapping. |
| E-13 | 行號年度累積結購/結售限額（選項：500萬/8000萬/5000萬/1000萬美元） | `explanation` empty — no confirmed-correct answer to build a mnemonic against. |
| E-23 | 非法買賣外匯常業罪刑期（選項：1/2/3/5年） | `explanation` empty — no confirmed-correct answer. |
| 新增-41 | BB+級公司債限額（選項：核定總額10%/業主權益20%/業主權益10%/核定總額2%） | `explanation` empty; too easily confused with the already-covered BBB級 "十權" rule if guessed wrong. |
| 新增-44, 新增-45, 新增-50, 新增-59 | Various numeric/list content | `explanation` empty in all cases. |
| B-4/C-4/D-6 family (廢止或撤銷許可, 六個月內未開辦 etc.) | 4–5 item list with an agency-name trap (金管會 vs 中央銀行) that shifts per exam set | Correct combination of items differs by exam-set variant due to trap options; a single fixed mnemonic phrase risks reinforcing the wrong combination for at least one variant. Left uncovered rather than risk it. |

## Notes for human reviewer

- **Highest scrutiny needed:** #2/#3 (`政庫軍`/`雙外`) and #7 (`關停命處`) — these compress
  multi-item keyword lists into acronyms of my own devising (not the author's literal
  words), so double-check the mapping from each character back to its Chinese-law source
  term.
- **#10 (`五十報`)** has a built-in ambiguity risk flagged above: "五十" could be
  misread as the bare number 50 rather than NT$500,000. Consider whether the phrase
  needs a clearer money-unit cue before approving.
- **#1, #4, #5** are the safest of the ten — the phrase itself is the *original* author's
  own text/shorthand, just formalized into a card; risk here is essentially limited to
  transcription error, which the self-review pass already checked against `answer`/
  `options`.
- Per the task's constraint, **no Supabase writes, no `mnemonic_cards` table changes, and
  no `approved` flips** were made by this task. All 10 rows above still need to be
  manually inserted (with `source: ai_generated`, `approved: false`) and then reviewed
  one by one.
