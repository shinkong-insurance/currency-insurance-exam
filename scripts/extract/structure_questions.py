import re

_PAGE = re.compile(r'參閱課本第\s*(\d+)\s*頁')
_EXPLANATION = re.compile(r'【解析】(.*)', re.S)
_OPTION_SPLIT = re.compile(r'\d\)\s*')

def structure_block(raw_text: str):
    text = " ".join(raw_text.split("\n")).strip()

    page_match = _PAGE.search(text)
    textbook_page = int(page_match.group(1)) if page_match else None

    exp_match = _EXPLANATION.search(text)
    explanation = exp_match.group(1).strip() if exp_match else ""
    before_explanation = text[:exp_match.start()] if exp_match else text
    before_explanation = _PAGE.sub("", before_explanation).strip()

    # 選項一律以 "數字)" 切，第一段(切割前的文字)是題幹
    parts = _OPTION_SPLIT.split(before_explanation)
    question = parts[0].strip()
    options = [p.strip() for p in parts[1:] if p.strip()]

    return {
        "question": question,
        "options": options,
        "explanation": explanation,
        "textbook_page": textbook_page,
    }
