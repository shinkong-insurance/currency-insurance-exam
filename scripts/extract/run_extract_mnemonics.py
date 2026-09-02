import json
from pathlib import Path
from extract_mnemonics import extract_mnemonic_from_block

BLOCKS = json.loads((Path(__file__).parent / "output/raw_blocks.json").read_text())
grouped = {}
for b in BLOCKS:
    r = extract_mnemonic_from_block(b["explanation_raw"])
    if not r:
        continue
    entry = grouped.setdefault(r["phrase"], {
        "phrase": r["phrase"], "meaning_raw": r["meaning_raw"], "related_question_nos": [],
    })
    entry["related_question_nos"].append({"exam_set": b["exam_set"], "question_no": b["question_no"]})

results = list(grouped.values())
out = Path(__file__).parent / "output/mnemonic_cards_original.json"
out.write_text(json.dumps(results, ensure_ascii=False, indent=2))
print(f"{len(results)} unique original mnemonic phrases found:")
for r in results:
    refs = ", ".join(f"{q['exam_set']}-{q['question_no']}" for q in r["related_question_nos"])
    print(f"  {r['phrase']}  (from: {refs})")
