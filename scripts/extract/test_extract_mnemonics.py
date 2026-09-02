from extract_mnemonics import extract_mnemonic_from_block

def test_extracts_explicit_koujue_marker():
    raw = """
    保險業資金運用於外匯存款，存放於同一銀行之金額，不得超過該保險業 1)業主權益百分之
    三 2)資金百分之五 3)業主權益百分之五 4)資金百分之三
    【解析】外匯存款→口訣 存放『金三角』→資金百分之三。
    """
    result = extract_mnemonic_from_block(raw)
    assert result is not None
    assert result["phrase"] == "金三角"

def test_extracts_koujue_without_quote_marks():
    raw = """
    保險業訂定國外投資風險監控管理措施，應包括有效執行之 Ａ風險管理政策 Ｂ風險管理架構
    Ｃ風險管理制度 1)ＢＣＤ 2)ＡＣＤ 3)ＡＢＣ 4)ＡＢＣＤ
    【解析】國外投資風險監控管理措施→口訣構政制
    """
    result = extract_mnemonic_from_block(raw)
    assert result is not None
    assert result["phrase"] == "構政制"

def test_returns_none_when_no_mnemonic_present():
    raw = "【解析】依保險法第146條規定，答案為第2項。"
    assert extract_mnemonic_from_block(raw) is None
