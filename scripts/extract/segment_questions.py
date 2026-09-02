import re

MARKER = re.compile(r'^\s*(\d{1,3})\s+([1-4])(?:\s|$)')
EXAM_SET_HEADER = re.compile(r'題號\s*答案')

def segment_text(text: str, exam_set: str):
    lines = text.split("\n")
    blocks = []
    current = None
    for line in lines:
        if EXAM_SET_HEADER.search(line):
            continue  # 跳過每頁重複的欄位標題列
        m = MARKER.match(line)
        if m:
            if current is not None:
                blocks.append(current)
            current = {
                "exam_set": exam_set,
                "question_no": int(m.group(1)),
                "answer": int(m.group(2)),
                "raw_text": line[m.end():] + "\n",
            }
        elif current is not None:
            current["raw_text"] += line + "\n"
    if current is not None:
        blocks.append(current)
    return blocks
