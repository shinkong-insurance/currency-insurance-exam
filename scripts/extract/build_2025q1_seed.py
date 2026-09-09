import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

BASE = "C:/Sthou/Documents/currency-insurance-exam/scripts/extract/output"
classified = json.load(open(BASE + "/fx2025q1_classified.json", encoding='utf-8'))

# Persistent id registry for this batch, mirroring the existing project
# convention (scripts/seed/question_id_registry.json): once a source "no"
# gets an id here, it never changes even if this script reruns or the
# candidate list is re-filtered later.
START_ID = 127
registry = {}
next_id = START_ID
for x in classified:
    registry[x['no']] = next_id
    next_id += 1

json.dump(registry, open(BASE + "/question_id_registry_2025q1.json", "w", encoding='utf-8'), ensure_ascii=False, indent=1)
print(f"Assigned ids {START_ID}..{next_id-1} ({len(registry)} questions)")

# Per-app-chapter sequential question_no, continuing after each chapter's
# current max (question_no is just a display ordinal, not unique across the
# whole table, so this only needs to be unique-ish within a chapter run).
import re

def esc(s):
    return s.replace("'", "''")

rows_sql = []
per_chapter_counter = {1: 100, 2: 100, 3: 100, 4: 100, 5: 100, 6: 100, 7: 100, 8: 100}
for x in classified:
    qid = registry[x['no']]
    chapter_id = x['app_chapter_id']
    qno = per_chapter_counter[chapter_id]
    per_chapter_counter[chapter_id] += 1
    opts = x['opts']
    opts_sql = "ARRAY[" + ",".join(f"'{esc(o)}'" for o in opts) + "]"
    q_sql = f"'{esc(x['q'])}'"
    ans = x['ans']
    src_no = x['no']
    rows_sql.append(
        f"({qid}, {chapter_id}, {qno}, {q_sql}, {opts_sql}, {ans}, '', null, null, false, null, '2025Q1', false, '{src_no}')"
    )

header = (
    "insert into questions "
    "(id, chapter_id, question_no, question, options, answer, explanation, "
    "keyword_hint, textbook_page, plain_explanation_reviewed, plain_explanation, exam_set, reviewed, source_no) "
    "values\n"
)
# source_no isn't a real column - drop it, it was just for my own sanity check
# while writing this; strip it back out before generating final SQL.
header = (
    "insert into questions "
    "(id, chapter_id, question_no, question, options, answer, explanation, "
    "keyword_hint, textbook_page, plain_explanation_reviewed, plain_explanation, exam_set, reviewed) "
    "values\n"
)
rows_sql_clean = []
for r in rows_sql:
    # drop the trailing , '<source_no>') -> ')'
    r2 = re.sub(r", '[^']*'\)$", ")", r)
    rows_sql_clean.append(r2)

CHUNK = 110
chunks = [rows_sql_clean[i:i+CHUNK] for i in range(0, len(rows_sql_clean), CHUNK)]
for i, chunk in enumerate(chunks):
    sql = header + ",\n".join(chunk) + ";\n"
    open(f"{BASE}/seed_2025q1_part{i+1}.sql", "w", encoding='utf-8').write(sql)
    print(f"Wrote seed_2025q1_part{i+1}.sql ({len(chunk)} rows)")

print(f"\nTotal rows: {len(rows_sql_clean)} in {len(chunks)} file(s)")
