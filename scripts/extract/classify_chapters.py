import re

# 依第一次出現的位置比對，所以放進 list 而非 dict（dict 在部分 Python 版本
# 不保證插入順序在比對時被尊重；用 list 明確保證「先出現的法規優先」）
_REGULATION_PATTERNS = [
    (2, re.compile(r'保險業辦理外匯業務管理辦法')),
    (3, re.compile(r'非投資型人身保險業務應具備資格條件及注意事項')),
    (4, re.compile(r'管理外匯條例')),
    (5, re.compile(r'外匯收支或交易申報辦法')),
    (6, re.compile(r'投資型保險投資管理辦法')),
    (7, re.compile(r'保險業辦理國外投資管理辦法')),
]

def classify_by_content(question: str, explanation: str):
    combined = f"{question} {explanation}"
    best_id, best_pos = None, None
    for chapter_id, pattern in _REGULATION_PATTERNS:
        m = pattern.search(combined)
        if m and (best_pos is None or m.start() < best_pos):
            best_id, best_pos = chapter_id, m.start()
    return best_id
