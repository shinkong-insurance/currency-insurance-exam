import json
from pathlib import Path
from build_levels import build_levels

questions = json.loads((Path(__file__).parent / "output/questions_seeded.json").read_text())
levels = build_levels(questions)
Path(__file__).parent.joinpath("output/levels.json").write_text(
    json.dumps(levels, ensure_ascii=False, indent=2))
print(f"共產生 {len(levels)} 關")
for lvl in levels:
    print(f"  {lvl['label']}: {len(lvl['question_ids'])} 題")
