from classify_chapters import classify_by_content, classify_fallback, classify

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

# ── classify_fallback (2026-09-09, ABCDE v3 的 191 題主題關鍵字規則) ──────
# 每個案例都是真實題目（或逐字節錄自簡報），對應的章節都對照過簡報實際
# 頁碼再寫進 classify_chapters.py，不是憑主題聯想猜的——見該檔案裡
# _FALLBACK_PATTERNS 上方的頁碼註記。

def test_fallback_classifies_ch1_opening_history_by_date():
    # 簡報第12頁「1.外幣保險開放紀事」逐字節錄
    q = "96.03.12中央銀行函復金管會，原則同意開放外幣非投資型保險業務，下列事項應配合辦理"
    assert classify_fallback(q, "") == 1

def test_fallback_classifies_ch2_policy_loan_business():
    # 真實題目 A-3（簡報第3條業務項目，第30頁）
    q = "以外幣收付之人身保險之保險單為質之外幣放款，屬於保險業得辦理之外匯業務"
    assert classify_fallback(q, "") == 2

def test_fallback_classifies_ch3_non_currency_specific_non_investment_business():
    # 真實題目 新增-32：規則原本要求「以外幣收付」，這裡是人民幣，且原規則
    # 要求逐字比對法規全名「以外幣收付之非投資型人身保險業務」
    q = "人身保險業銷售以人民幣收付之非投資型人身保險商品，應符合下列哪些規定"
    assert classify_fallback(q, "") == 3

def test_fallback_classifies_ch5_not_ch7_for_overseas_investment_fund_remittance():
    # 真實題目 A-23/C-22/D-28/E-32/E-49 都是這個開頭；這整個「匯出資金」主題
    # 實際上在簡報第140頁，掛在「外匯收支或交易申報辦法」（ch5）底下，不是
    # 直覺以為的「保險業辦理國外投資管理辦法」（ch7）——這是查證過程中抓到
    # 的一個真實案例，值得用測試鎖住避免之後被改回猜測的 ch7。
    q = "壽險業者辦理國外投資，可在金管會核定投資比率範圍內，以下列方式匯出資金"
    assert classify_fallback(q, "") == 5

def test_fallback_classifies_ch6_var_risk_value_definition():
    # 真實題目 A-47/B-47/E-16/E-17（簡報第75-76頁，投資型保險投資管理辦法
    # 第19條第1項第3款的風險值定義延伸說明）
    q = "人身保險業國外投資部分已採用計算風險值評估風險，所稱之風險值，係指按週為基礎"
    assert classify_fallback(q, "") == 6

def test_fallback_classifies_ch7_overseas_real_estate_and_alternative_investments():
    # 真實題目 C-30（簡報第164-165頁，國外及大陸地區不動產投資）
    assert classify_fallback("保險業對國外及大陸地區不動產之投資，應如何", "") == 7
    # 真實題目 A-35（簡報第182頁，另類投資限制）
    assert classify_fallback("保險業有下列何種情事者，不得投資商品基金及基礎建設基金", "") == 7

def test_fallback_returns_none_for_genuinely_general_ch8_content():
    # 「整體性投資政策」「資產管理自律規範」是簡報194-200頁的獨立法規
    # （保險業資產管理自律規範），不屬於 ch1-7 任何一個六大法規，刻意沒有
    # 對應規則，維持 None（呼叫端歸到 ch8），這是正確答案不是遺漏。
    assert classify_fallback("保險業訂立之整體性投資政策，至少多久應重新檢討一次", "") is None

def test_classify_tries_regulation_name_first_then_falls_back():
    # classify_by_content 先贏；只有它找不到時才試 classify_fallback
    q = "依「管理外匯條例」規定，96.03.12中央銀行函復金管會，原則同意開放外幣非投資型保險業務"
    assert classify(q, "") == 4  # 法規全名優先，不會被 ch1 的 fallback 搶走

def test_classify_uses_fallback_when_no_regulation_name_present():
    q = "96.03.12中央銀行函復金管會，原則同意開放外幣非投資型保險業務"
    assert classify(q, "") == 1

# ── 第二輪擴充（廣義但緊扣法規本身用詞，不是主題聯想）─────────────────

def test_fallback_classifies_ch2_fill_in_the_blank_regulation_name():
    # 真實題目 B-1：題目本身就是在問「保險業辦理外匯業務管理辦法」這個
    # 法規全名（空格處的答案），邏輯結構決定答案，跟簡報頁碼無關。
    q = "中央銀行於96年4月23日訂定發布______辦法，以供保險業辦理外匯業務遵循"
    assert classify_fallback(q, "") == 2

def test_fallback_classifies_ch3_non_investment_type_regardless_of_currency():
    # 真實題目 A-25：不限「外幣」兩字，只要是非投資型人身保險的規定即可
    assert classify_fallback("以外幣收付之非投資型人身保險契約，其對應之一般帳簿資產應如何", "") == 3
    # 真實題目 C-23
    assert classify_fallback("以外幣收付之非投資型死亡保險，依保險期間區分，分為", "") == 3

def test_fallback_classifies_ch5_declaration_and_settlement_actions():
    # 真實題目 A-20/B-20/C-20/D-24 這類「申報義務人得逕行辦理新台幣結匯」題
    q = "下列何項外匯收支或交易，申報義務人得於填妥申報書後，逕行辦理新台幣結匯"
    assert classify_fallback(q, "") == 5

def test_fallback_classifies_ch6_investment_linked_insurance_vocabulary():
    # 真實題目 A-2：投資型/專設帳簿字樣，不是「非投資型」
    q = "投資型保險與非投資型保險的最大差別為投資型保險具有專設帳簿"
    assert classify_fallback(q, "") == 6

def test_fallback_ch6_non_investment_type_still_wins_ch3_over_ch6_keyword_collision():
    # 「投資型保險與非投資型保險」這種對照句同時含「非投資型」（ch3 詞彙）
    # 和「投資型保險」（ch6 詞彙）；用真實題目 D-1 驗證此時仍以先出現的
    # 文字位置決定（D-1 開頭是「投資型保險與非投資型保險之敍述」，
    # 「投資型保險」出現在「非投資型保險」之前，故仍判為 ch6，跟真實題庫
    # 這題原本要考的「投資型 vs 非投資型」比較主題一致）。
    q = "有關投資型保險與非投資型保險之敍述，何者不正確"
    assert classify_fallback(q, "") == 6

def test_fallback_classifies_ch7_overseas_investment_fund_vocabulary():
    # 真實題目 A-26/A-27/B-25/C-25 這類「保險業資金/國外投資」核心用詞
    assert classify_fallback("下列何者為保險業辦理國外投資之項目", "") == 7
    assert classify_fallback("保險業資金投資以外幣計價之商業本票，其發行或保證公司之信用評等等級須經國外信用評等機構評定為何種等級", "") == 7

def test_fallback_classifies_ch2_reinsurer_fx_business_approval():
    # 簡報第31頁逐字：「再保險業者之經營其有涉及外匯業務者，應經中央銀行
    # 許可後始得辦理」——真實題目 C-6/E-38 都是這句話的填空/問答變體
    assert classify_fallback("再保險業者之經營其有涉及外匯業務者，是否應經何者許可後始得辦理", "") == 2
    assert classify_fallback("再保險業者之經營其有涉及外匯業務者，______許可後始得辦理", "") == 2

def test_fallback_classifies_ch5_settlement_requiring_prior_approval_not_just_direct():
    # 真實題目 A-21：跟前面「逕行辦理」的直接結匯不同，這題問的是「需要
    # 先申請核准」才能結匯的情況，一樣是外匯收支或交易申報辦法的規定
    q = "下列何者不是申報義務人應於檢附所填申報書及相關證明文件，經由銀行業向中央銀行申請核准後，始得辦理新台幣結匯之外匯收支或交易"
    assert classify_fallback(q, "") == 5

def test_fallback_classifies_ch7_fill_in_the_blank_overseas_investment():
    # 真實題目 C-31：空格夾在「保險業辦理」跟「之國外投資」中間
    q = "保險業辦理______之國外投資，須經主管機關核准後始得辦理"
    assert classify_fallback(q, "") == 7

def test_fallback_classifies_ch1_opening_history_regardless_of_clause_order():
    # 真實題目 新增-30/新增-43 把「中央銀行」放在最前面，跟簡報原文
    # （96.03.12中央銀行函復金管會...）的詞序不同，兩種詞序都要認得
    q = "中央銀行於96年3月12日函復金管會，原則同意開放外幣非投資型保險業務"
    assert classify_fallback(q, "") == 1
