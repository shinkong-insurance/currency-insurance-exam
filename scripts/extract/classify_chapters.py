import re

# 用 list 而非 dict：比對結果採「文字中先出現者優先」，判斷依據是每個
# pattern.search() 命中的 m.start() 位置高低，跟 list/dict 的走訪順序本身
# 無關（dict 自 3.7 起也保證插入順序）。用 list 只是讓「六個法規、各自
# 對應一個 chapter_id」這個對應關係讀起來直接，並不是走訪順序的正確性依據。
_REGULATION_PATTERNS = [
    (2, re.compile(r'保險業(?:申請)?辦理外匯業務管理辦法')),
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
