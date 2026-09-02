import re

EXAM_LABEL = re.compile(r'^(A卷|B卷|C卷|D卷|E卷|新增)$')

def detect_exam_set(header_row):
    for cell in header_row:
        if cell:
            m = EXAM_LABEL.match(cell.strip())
            if m:
                return m.group(1).replace('卷', '')
    return None

def parse_table_row(row, current_exam_set):
    if len(row) != 4:
        return None
    qno, ans, qtext, exp = row
    if qno is None or ans is None or qtext is None:
        return None
    try:
        qno_i = int(qno.strip())
        ans_i = int(ans.strip())
    except (ValueError, AttributeError):
        return None
    return {
        "exam_set": current_exam_set,
        "question_no": qno_i,
        "answer": ans_i,
        "question_raw": qtext,
        "explanation_raw": exp or "",
    }
