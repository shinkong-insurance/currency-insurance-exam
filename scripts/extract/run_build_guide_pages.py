import json
from pathlib import Path
from build_guide_pages import build_guide_pages

ranges = json.loads((Path(__file__).parent / "chapter_page_ranges.json").read_text())
result = build_guide_pages(ranges)
repo_root = Path(__file__).resolve().parent.parent.parent
out = repo_root / "assets" / "json" / "guide_pages.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, ensure_ascii=False, indent=2))
print(f"guide_pages.json written, {len(result['chapters'])} chapters")
