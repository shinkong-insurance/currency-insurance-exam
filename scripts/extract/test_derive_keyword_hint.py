from derive_keyword_hint import derive_keyword_hint


def test_extracts_arrow_segment():
    assert derive_keyword_hint("結匯→向銀行業辦理") == "結匯→向銀行業辦理"


def test_falls_back_to_truncated_explanation_when_no_arrow():
    text = "依保險法第146條規定，本題答案為第2項，因為該項符合國外投資範圍之定義"
    hint = derive_keyword_hint(text)
    assert len(hint) <= 40
    assert hint.startswith("依保險法第146條規定")
