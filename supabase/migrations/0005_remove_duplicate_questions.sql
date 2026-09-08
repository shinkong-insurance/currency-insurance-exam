-- supabase/migrations/0005_remove_duplicate_questions.sql
-- 考生實測回報「同樣的題目會重複」。查證屬實：原始題庫 PDF 的「新增」(E) 卷
-- 逐字重複了 A/B/C 卷已經出過的題目，抽取流程把它們當成全新題目各自建了 id
-- （2026-09-04 放寬 ch3 分類規則、題數從 114 灌到 126 題那次帶進來的），
-- 造成同一段文字在 questions 表裡有兩個不同 id。
--
-- 這裡刪除每組重複裡「新增(E)卷」那一份，保留原本 A/B/C 卷的 id：
--   保留 id 1  (A#3)  ↔ 刪除 id 87 (E#35) — ch2
--   保留 id 4  (A#6)  ↔ 刪除 id 89 (E#37) — ch2
--   保留 id 9  (A#12) ↔ 刪除 id 94 (E#43) — ch6
--   保留 id 10 (A#16) ↔ 刪除 id 95 (E#45) — ch4
--   保留 id 25 (B#10) ↔ 刪除 id 93 (E#42) — ch6
--   保留 id 40 (C#9)  ↔ 刪除 id 92 (E#41) — ch6
--   保留 id 44 (C#17) ↔ 刪除 id 97 (E#47) — ch4
--   保留 id 48 (C#27) ↔ 刪除 id 99 (E#50) — ch7
-- 確認過刪除前：key_favorites/key_wrong_answers 都沒有任何學員資料引用這 8 個
-- 被刪的 id（對話中已查證），不會弄丟真實學員的收藏/錯題紀錄。

-- 1. mnemonic_cards.related_question_ids：口訣卡「十權」原本連到 [48,99]，
--    99 要刪，移除後只留原本的 48。
update mnemonic_cards
  set related_question_ids = array_remove(related_question_ids, 99)
  where related_question_ids @> array[99];

-- 2. levels.question_ids：受影響的 6 個關卡各少 1 題；第6章第5關同時含
--    93、94 兩個要刪的 id，從原本 6 題變 4 題，其餘關卡各少 1 題。
update levels set question_ids = array_remove(question_ids, 87) where question_ids @> array[87];
update levels set question_ids = array_remove(question_ids, 89) where question_ids @> array[89];
update levels set question_ids = array_remove(question_ids, 92) where question_ids @> array[92];
update levels set question_ids = array_remove(question_ids, 93) where question_ids @> array[93];
update levels set question_ids = array_remove(question_ids, 94) where question_ids @> array[94];
update levels set question_ids = array_remove(question_ids, 95) where question_ids @> array[95];
update levels set question_ids = array_remove(question_ids, 97) where question_ids @> array[97];
update levels set question_ids = array_remove(question_ids, 99) where question_ids @> array[99];

-- 3. 最後刪除重複題本身。
delete from questions where id in (87,89,92,93,94,95,97,99);
