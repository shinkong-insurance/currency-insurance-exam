import json
from pathlib import Path
from extract_mnemonics import extract_mnemonic_from_block

BLOCKS = json.loads((Path(__file__).parent / "output/raw_blocks.json").read_text())

# Group matches by phrase
phrases_dict = {}
for b in BLOCKS:
    r = extract_mnemonic_from_block(b["raw_text"])
    if r:
        phrase = r["phrase"]
        if phrase not in phrases_dict:
            phrases_dict[phrase] = {
                "phrase": phrase,
                "meaning_raw": r["meaning_raw"],
                "related_question_nos": []
            }
        phrases_dict[phrase]["related_question_nos"].append({
            "exam_set": b["exam_set"],
            "question_no": b["question_no"]
        })

# Convert to list and write output
results = list(phrases_dict.values())
out = Path(__file__).parent / "output/mnemonic_cards_original.json"
out.write_text(json.dumps(results, ensure_ascii=False, indent=2))

print(f"{len(results)} unique original mnemonic phrases found:")
for r in results:
    question_refs = ", ".join(
        f"{qn['exam_set']}-{qn['question_no']}"
        for qn in r["related_question_nos"]
    )
    print(f"  {r['phrase']!r} → [{question_refs}]")
