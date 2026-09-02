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
    # 這份表格抽取結果中，換行只代表同一儲存格內文字因欄寬不足而換行，
    # 從未代表真正需要空格的語意邊界（中文本身不需詞間空格；且已確認
    # 資料中沒有任何選項標記「數字)」或任何英文單字跨行被拆開）。用空
    # 白字元拼接會在被換行截斷的詞中間留下一個假的空格（例如「金管會」
    # 被拆成「金管」/「會」兩行，會變成「金管 會」）。故直接相接、不加分隔符。
    q_text = "".join(question_raw.split("\n")).strip()
    exp_text = "".join(explanation_raw.split("\n")).strip()

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
