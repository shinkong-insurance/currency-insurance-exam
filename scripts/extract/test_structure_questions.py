from structure_questions import structure_block

def test_simple_four_choice():
    raw = """付之款項向______辦理結匯，並應將結匯明細資料留存以供查核。 1)銀行業 2)中央銀行
        3)財政部 4)金管會
        參閱課本第23頁
        【解析】結匯→向銀行業辦理"""
    result = structure_block(raw)
    assert result["textbook_page"] == 23
    assert result["explanation"] == "結匯→向銀行業辦理"
    assert len(result["options"]) == 4
    assert result["options"][0] == "銀行業"

def test_lettered_combination_choice():
    raw = """依「保險業辦理外匯業務管理辦法」規定，保險業得申請辦理下列哪些外匯業務：A以外幣收付
        之人身保險業務B以外幣收付之非投資型年金保險 1) A B C 2) A C 3) B D 4) C D
        參閱課本第20頁
        【解析】B外投年轉臺 D外幣放款"""
    result = structure_block(raw)
    assert result["options"] == ["A B C", "A C", "B D", "C D"]
    assert "外投年轉臺" in result["explanation"]
