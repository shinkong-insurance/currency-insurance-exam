from classify_chapters import classify_by_content

def test_classifies_by_regulation_name_in_question():
    q = "依「投資型保險投資管理辦法」第12條規定，保險人行使投資型保險專設帳簿持有股票之投票表決權者..."
    assert classify_by_content(q, "") == 6

def test_classifies_by_regulation_name_in_explanation():
    assert classify_by_content("下列何者正確？", "依「管理外匯條例」第4條規定，答案為第2項") == 4

def test_returns_none_when_no_known_regulation_named():
    assert classify_by_content("下列何者為外幣保險開放的正確歷程？", "詳見課程說明") is None

def test_first_mentioned_regulation_wins_when_both_present():
    q = "「保險業辦理外匯業務管理辦法」與「管理外匯條例」的關係為何？"
    assert classify_by_content(q, "") == 2
