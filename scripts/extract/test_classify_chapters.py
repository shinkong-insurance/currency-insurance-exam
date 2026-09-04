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

def test_classifies_ch3_questions_that_omit_the_regulations_full_suffix():
    # Real questions (B-49/C-49/E-4/D-30/E-34) state the regulation's subject
    # ("人身保險業辦理以外幣收付之非投資型人身保險業務") but never append its
    # full title suffix ("...應具備資格條件及注意事項"), so the old exact
    # pattern missed them entirely.
    q = ("人身保險業辦理以外幣收付之非投資型人身保險業務，應由內部稽核單位"
         "______辦理該等保險商品招攬、核保、理賠、精算、保全、法務及投資"
         "作業之專案查核。")
    assert classify_by_content(q, "") == 3

def test_ch3_short_phrase_does_not_steal_from_an_earlier_ch2_match():
    # Regression guard for the widened ch3 pattern: a question naming ch2's
    # regulation earlier in the text (modeled on real question B-42) must
    # still classify to ch2, not get stolen by the shorter ch3 phrase that
    # also appears later in the same text.
    q = ("壽險業辦理歐元計價之非投資型人身保險商品相關業務，請確實依據哪些"
         "規定辦理 A保險業辦理外匯業務管理辦法 B人身保險業辦理以外幣收付之"
         "非投資型人身保險業務應具備資格條件及注意事項")
    assert classify_by_content(q, "") == 2

def test_first_mentioned_wins_by_text_position_not_pattern_list_order():
    # Regression guard: chapter 4's pattern comes BEFORE chapter 5's in
    # _REGULATION_PATTERNS, but chapter 5's regulation is named earlier in
    # this text (modeled on real question 新增-44). A buggy implementation
    # that just returns the first pattern-list entry it finds anywhere in
    # the text (rather than comparing match positions) would wrongly return
    # 4 here instead of 5.
    q = ("依「外匯收支或交易申報辦法」第15條規定，申報義務人因下列哪種行為"
         "應依「管理外匯條例」第20條第1項規定受罰")
    assert classify_by_content(q, "") == 5
