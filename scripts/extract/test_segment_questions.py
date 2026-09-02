from segment_questions import parse_table_row, detect_exam_set

def test_parses_valid_question_row():
    row = ["10", "4",
           "「投資型保險投資管理辦法」第12條規定...不得有下列哪些情事：\n1)AB 2)ABCD 3)A 4)ABC",
           "參閱課本第32頁\n【解析】D選項錯在\"要保人\"，應為\"保險人\""]
    block = parse_table_row(row, current_exam_set="A")
    assert block["exam_set"] == "A"
    assert block["question_no"] == 10
    assert block["answer"] == 4
    assert "不得有下列哪些情事" in block["question_raw"]
    assert "【解析】" in block["explanation_raw"]

def test_returns_none_for_header_row():
    row = ["題號", "答案", "A卷", "答案說明"]
    assert parse_table_row(row, current_exam_set="A") is None

def test_returns_none_for_malformed_row():
    assert parse_table_row(["1", None, "text", "exp"], current_exam_set="A") is None
    assert parse_table_row(["not-a-number", "4", "text", "exp"], current_exam_set="A") is None

def test_detects_exam_set_label_from_header():
    assert detect_exam_set(["題號", "答案", "A卷", "答案說明"]) == "A"
    assert detect_exam_set(["題號", "答案", "新增", "答案說明"]) == "新增"
    assert detect_exam_set(["10", "4", "some question", "some explanation"]) is None
