from fix_raw_text import apply_known_fixes
from structure_questions import structure_block


def _block(exam_set, question_no, question_raw, explanation_raw=""):
    return {
        "exam_set": exam_set,
        "question_no": question_no,
        "answer": 1,
        "question_raw": question_raw,
        "explanation_raw": explanation_raw,
    }


def test_leaves_unrelated_blocks_untouched():
    blocks = [_block("A", 1, "unrelated question text 1)a 2)b 3)c 4)d")]
    fixed = apply_known_fixes(blocks)
    assert fixed == blocks
    assert fixed is not blocks  # returns a new list, doesn't mutate in place


def test_fixed_blocks_structure_into_four_clean_options():
    # every patched (exam_set, question_no) should structure cleanly into
    # exactly 4 options once the known source-text defect is patched
    raw_blocks = [
        _block("新增", 4, "placeholder"),
        _block("新增", 6, "placeholder"),
        _block("新增", 9, "placeholder"),
        _block("新增", 15, "placeholder"),
        _block("新增", 70, "placeholder"),
        _block("A", 36, "placeholder"),
        _block("E", 33, "placeholder"),
        _block("新增", 36, "placeholder"),
    ]
    fixed = apply_known_fixes(raw_blocks)
    for b in fixed:
        s = structure_block(b["question_raw"], b["explanation_raw"])
        assert len(s["options"]) == 4, (b["exam_set"], b["question_no"], s["options"])


def test_new_4_option3_no_longer_missing_closing_paren():
    fixed = apply_known_fixes([_block("新增", 4, "placeholder")])
    s = structure_block(fixed[0]["question_raw"], "")
    assert s["options"] == ["ABCD", "BCD", "ABC", "ACD"]


def test_new_70_uses_circled_digit_normalized_and_fills_known_wording():
    fixed = apply_known_fixes([_block("新增", 70, "placeholder")])
    s = structure_block(fixed[0]["question_raw"], "")
    assert len(s["options"]) == 4
    assert s["options"][3] == "最近一年公平待客原則評核結果為人身保險業前百分之七十。"


def test_a_36_and_e_33_and_new_36_match_the_clean_v1_wording():
    fixed = apply_known_fixes([
        _block("A", 36, "placeholder", "placeholder"),
        _block("E", 33, "placeholder"),
        _block("新增", 36, "placeholder"),
    ])
    by_key = {(b["exam_set"], b["question_no"]): b for b in fixed}

    a36 = structure_block(by_key[("A", 36)]["question_raw"], by_key[("A", 36)]["explanation_raw"])
    assert a36["options"] == ["衡量日", "實際入帳時", "中央銀行結帳", "各銀行結帳之匯率計算"]
    assert a36["explanation"] == "新增減投資→實際入帳時之匯率"

    e33 = structure_block(by_key[("E", 33)]["question_raw"], "")
    assert e33["options"] == ["五年", "二年", "三年", "一年"]

    n36 = structure_block(by_key[("新增", 36)]["question_raw"], "")
    assert n36["options"] == [
        "於受理轉換申請時，應事先告知要保人",
        "以公告方式通知要保人",
        "應於10日內通知要保人",
        "應以不低於60日之期間內。",
    ]
