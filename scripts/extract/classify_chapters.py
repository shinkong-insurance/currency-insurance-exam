import re

# 用 list 而非 dict：比對結果採「文字中先出現者優先」，判斷依據是每個
# pattern.search() 命中的 m.start() 位置高低，跟 list/dict 的走訪順序本身
# 無關（dict 自 3.7 起也保證插入順序）。用 list 只是讓「六個法規、各自
# 對應一個 chapter_id」這個對應關係讀起來直接，並不是走訪順序的正確性依據。
_REGULATION_PATTERNS = [
    (2, re.compile(r'保險業(?:申請)?辦理外匯業務管理辦法')),
    # 原本只認完整法規全名「…應具備資格條件及注意事項」，但同一份題庫裡
    # 有幾題（B-49、C-49、E-4、D-30、E-34）只寫了法規名稱的前半段「人身
    # 保險業辦理以外幣收付之非投資型人身保險業務」就直接接題目本文，沒有
    # 完整點出「應具備資格條件及注意事項」，導致原本的規則抓不到、被排除
    # 在已分類的 121 題之外。放寬成只認這段前半段——已對整個題庫的 121
    # 題全量檢查過，這個短語只出現在 14 題裡，其餘 11 題原本就分類到 ch3
    # 或本來就沒分類，沒有任何一題會因為放寬而從其他章節被搶走（例如 B-42
    # 同時提到 ch2 的「保險業辦理外匯業務管理辦法」，但那個字串出現在題幹
    # 更前面的位置，比對邏輯本來就是「先出現者優先」，所以 B-42 依然正確
    # 分類到 ch2，不受影響）。
    (3, re.compile(r'人身保險業辦理以外幣收付之非投資型人身保險業務')),
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
