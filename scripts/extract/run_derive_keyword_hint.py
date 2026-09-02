import json
from pathlib import Path
from derive_keyword_hint import derive_keyword_hint

PATH = Path(__file__).parent / "output/questions_with_chapter.json"
questions = json.loads(PATH.read_text())
for q in questions:
    q["keyword_hint"] = derive_keyword_hint(q["explanation"])
PATH.write_text(json.dumps(questions, ensure_ascii=False, indent=2))
print(f"keyword_hint 已補上 {len(questions)} 筆")
