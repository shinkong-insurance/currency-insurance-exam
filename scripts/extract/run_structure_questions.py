import json
from pathlib import Path
from structure_questions import structure_block

BLOCKS = json.loads((Path(__file__).parent / "output/raw_blocks.json").read_text())
structured, needs_review = [], []
for b in BLOCKS:
    s = structure_block(b["question_raw"], b["explanation_raw"])
    s.update({"exam_set": b["exam_set"], "question_no": b["question_no"]})
    if len(s["options"]) != 4:
        needs_review.append(s)
    else:
        structured.append(s)

Path(__file__).parent.joinpath("output/questions_structured.json").write_text(
    json.dumps(structured, ensure_ascii=False, indent=2))
Path(__file__).parent.joinpath("output/questions_needs_review.json").write_text(
    json.dumps(needs_review, ensure_ascii=False, indent=2))

print(f"structured cleanly: {len(structured)}")
print(f"needs manual review (options != 4): {len(needs_review)}")
