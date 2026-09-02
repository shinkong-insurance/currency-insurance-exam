import json
from pathlib import Path
from classify_chapters import classify_by_content

QUESTIONS = json.loads((Path(__file__).parent / "output/questions_structured.json").read_text())

classified, unclassified = [], []
for q in QUESTIONS:
    cid = classify_by_content(q["question"], q["explanation"])
    if cid is None:
        unclassified.append(q)
    else:
        q["chapter_id"] = cid
        classified.append(q)

Path(__file__).parent.joinpath("output/questions_with_chapter.json").write_text(
    json.dumps(classified, ensure_ascii=False, indent=2))
print(f"classified: {len(classified)}, unclassified: {len(unclassified)}")
for q in unclassified[:20]:
    print(f"  [{q['exam_set']}-{q['question_no']}] {q['question'][:40]}")
