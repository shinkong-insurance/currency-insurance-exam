import json
from pathlib import Path
from extract_mnemonics import extract_mnemonic_from_block

BLOCKS = json.loads((Path(__file__).parent / "output/raw_blocks.json").read_text())
results = []
for b in BLOCKS:
    r = extract_mnemonic_from_block(b["raw_text"])
    if r:
        r["exam_set"] = b["exam_set"]
        r["question_no"] = b["question_no"]
        results.append(r)

out = Path(__file__).parent / "output/mnemonic_cards_original.json"
out.write_text(json.dumps(results, ensure_ascii=False, indent=2))
print(f"{len(results)} original mnemonic phrases found:")
for r in results:
    print(f"  [{r['exam_set']}-{r['question_no']}] {r['phrase']}")
