import re

_PAGE = re.compile(r'參閱課本第\s*(\d+)')
_EXPLANATION = re.compile(r'【解析】(.*)', re.S)

# A-E 卷全部使用「數字)」(無左括號)。「新增」卷則混用兩種格式：
# 「(數字)」或「(英文字母)」，且兩者互斥、皆固定切出 4 段。優先比對較獨特
# 的括號格式，避免通用的「數字)」規則誤吃到「(1)」裡的「1)」子字串而在
# 選項前殘留一個孤立的左括號。
_OPT_LETTER_PAREN = re.compile(r'\([A-D]\)\s*')
_OPT_DIGIT_PAREN = re.compile(r'\(\d\)\s*')
_OPTION_SPLIT = re.compile(r'\d\)\s*')

# 這份資料其實混用了兩種「字母組合答案」排版慣例：有些整組緊貼不留空格
# （例如「BCD」），有些字母之間刻意留空格（例如「A B C」，brief 本身的
# test_lettered_combination_choice 測資就是這種）。換行只代表同一儲存格
# 內文字因欄寬不足而換行的印刷斷行，本身不帶語意——但由於這兩種慣例並
# 存，換行恰好落在哪裡完全是版面決定的巧合，不能一律當作「不需要空格」
# 直接相接（那樣會把 "A B C" 斷行後的 "A\nB C" 誤黏成錯誤的 "AB C"，或
# 把換行處於半形字元/數字中間的內容，例如頁碼區間 "115%" 誤黏成
# "70115%"）。安全的預設作法（也是 brief 原本的寫法）是換行一律先接空
# 格；空格只有在恰好把「同一個」中文字/全形字词从中間斷開時才是錯的
# （中文本身不需要詞間空格），所以只在換行「前一字」與「後一字」兩邊都
# 屬於中日韓統一表意文字或全形符號區塊時，才把這個空格收掉，其餘一律保
# 留空格（含半形英數字元邊界，如 "A"/"B C"、"41-70"/"115%"）。
_CJK = r'[一-鿿＀-￯]'
_CJK_LINE_WRAP = re.compile(r'(?<=' + _CJK + r')\s*\n\s*(?=' + _CJK + r')')

def _rejoin_lines(text: str) -> str:
    text = _CJK_LINE_WRAP.sub('', text)
    return " ".join(text.split("\n")).strip()

def _split_options(q_text: str):
    if _OPT_LETTER_PAREN.search(q_text):
        pattern = _OPT_LETTER_PAREN
    elif _OPT_DIGIT_PAREN.search(q_text):
        pattern = _OPT_DIGIT_PAREN
    else:
        pattern = _OPTION_SPLIT
    parts = pattern.split(q_text)
    question = parts[0].strip()
    options = [p.strip() for p in parts[1:] if p.strip()]
    return question, options

def structure_block(question_raw: str, explanation_raw: str):
    q_text = _rejoin_lines(question_raw)
    exp_text = _rejoin_lines(explanation_raw)

    page_match = _PAGE.search(exp_text)
    textbook_page = int(page_match.group(1)) if page_match else None

    exp_match = _EXPLANATION.search(exp_text)
    explanation = exp_match.group(1).strip() if exp_match else _PAGE.sub("", exp_text).strip()

    # 選項一律以「數字)」或「(數字)」或「(英文字母)」切，第一段是題幹
    question, options = _split_options(q_text)

    return {
        "question": question,
        "options": options,
        "explanation": explanation,
        "textbook_page": textbook_page,
    }
