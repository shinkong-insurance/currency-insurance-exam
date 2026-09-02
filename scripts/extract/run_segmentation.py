import json, subprocess, re
from pathlib import Path
from segment_questions import segment_text, EXAM_SET_HEADER

PDF = Path.home() / "Documents/外幣/外幣題庫_ABECD卷整理(含新增)V1.pdf"
OUT = Path(__file__).parent / "output/raw_blocks.json"

def extract_full_text() -> str:
    return subprocess.run(
        ["pdftotext", "-layout", str(PDF), "-"],
        capture_output=True, text=True, check=True
    ).stdout

def split_by_exam_set(full_text: str):
    # 用「題號 答案 ... X卷 ... 答案說明」列偵測卷別切換
    parts, current_set, buf = [], None, []
    for line in full_text.split("\n"):
        if EXAM_SET_HEADER.search(line):
            m = re.search(r'(A卷|B卷|C卷|D卷|E卷|新增)', line)
            label = m.group(1) if m else current_set
            # Normalize label: strip "卷" suffix
            if label and label.endswith("卷"):
                label = label[:-1]  # Remove "卷"
            if label != current_set and buf:
                parts.append((current_set, "\n".join(buf)))
                buf = []
            current_set = label
        buf.append(line)
    if buf:
        parts.append((current_set, "\n".join(buf)))
    return parts

if __name__ == "__main__":
    full_text = extract_full_text()
    all_blocks = []
    for exam_set, chunk in split_by_exam_set(full_text):
        all_blocks.extend(segment_text(chunk, exam_set))
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(all_blocks, ensure_ascii=False, indent=2))
    print(f"{len(all_blocks)} blocks written to {OUT}")
    assert 200 <= len(all_blocks) <= 320, f"unexpected block count: {len(all_blocks)}"
    sets_present = {b["exam_set"] for b in all_blocks}
    assert {"A", "B", "C", "D", "E", "新增"}.issubset(sets_present), sets_present
