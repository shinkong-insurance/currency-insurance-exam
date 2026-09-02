from extract_mnemonics import extract_mnemonic_from_block

def test_extracts_explicit_koujue_marker():
    explanation_raw = "參閱課本第84頁\n【解析】外匯存款→口訣 存放『金三角』→資金百分之三。"
    result = extract_mnemonic_from_block(explanation_raw)
    assert result is not None
    assert result["phrase"] == "金三角"

def test_extracts_koujue_without_quote_marks():
    explanation_raw = "參閱課本第113頁\n【解析】國外投資風險監控管理措施→口訣構政制"
    result = extract_mnemonic_from_block(explanation_raw)
    assert result is not None
    assert result["phrase"] == "構政制"

def test_returns_none_when_no_mnemonic_present():
    explanation_raw = "參閱課本第10頁\n【解析】依保險法第146條規定，答案為第2項。"
    assert extract_mnemonic_from_block(explanation_raw) is None
