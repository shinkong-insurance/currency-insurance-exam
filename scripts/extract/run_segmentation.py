import json
import pdfplumber
from pathlib import Path
from segment_questions import parse_table_row, detect_exam_set

PDF = Path.home() / "Documents/外幣/外幣題庫_ABECD卷整理(含新增)V1.pdf"
OUT = Path(__file__).parent / "output/raw_blocks.json"

def extract_all_blocks():
    all_blocks = []
    current_set = None
    with pdfplumber.open(str(PDF)) as pdf:
        for page in pdf.pages:
            for table in page.extract_tables():
                if not table:
                    continue
                detected = detect_exam_set(table[0])
                if detected:
                    current_set = detected
                for row in table[1:]:
                    block = parse_table_row(row, current_set)
                    if block:
                        all_blocks.append(block)
    return all_blocks

if __name__ == "__main__":
    all_blocks = extract_all_blocks()
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(all_blocks, ensure_ascii=False, indent=2))
    print(f"{len(all_blocks)} blocks written to {OUT}")
    assert 200 <= len(all_blocks) <= 320, f"unexpected block count: {len(all_blocks)}"
    sets_present = {b["exam_set"] for b in all_blocks}
    assert {"A", "B", "C", "D", "E", "新增"}.issubset(sets_present), sets_present
