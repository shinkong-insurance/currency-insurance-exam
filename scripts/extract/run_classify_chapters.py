import json
from pathlib import Path
from classify_chapters import classify_page

RANGES = json.loads((Path(__file__).parent / "chapter_page_ranges.json").read_text())
QUESTIONS = json.loads((Path(__file__).parent / "output/questions_structured.json").read_text())

classified, unclassified = [], []
for q in QUESTIONS:
    cid = classify_page(q["textbook_page"], RANGES) if q["textbook_page"] else None
    if cid is None:
        unclassified.append(q)
    else:
        q["chapter_id"] = cid
        classified.append(q)

Path(__file__).parent.joinpath("output/questions_with_chapter.json").write_text(
    json.dumps(classified, ensure_ascii=False, indent=2))
print(f"classified: {len(classified)}, unclassified: {len(unclassified)}")
for q in unclassified[:20]:
    print(f"  [{q['exam_set']}-{q['question_no']}] page={q['textbook_page']} {q['question'][:30]}")
