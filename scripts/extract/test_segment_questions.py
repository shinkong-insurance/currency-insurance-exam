from segment_questions import segment_text

FIXTURE = """題號 答案                           A卷                                 答案說明
1   3
        95年3月14日金管會保險局...等配套措施下，可正面考量開放外幣傳統型保單：
        1)BCD 2)ACD 3)ABD 4)ABC          【解析】沒有C保險費收取方式
2   4   投資型保險與非投資型保險的最大差別...等特色 1)BCDE 2)ACDE 3)ACDE 4)ABCD
"""

def test_segment_splits_on_question_markers():
    blocks = segment_text(FIXTURE, exam_set="A")
    assert len(blocks) == 2
    assert blocks[0]["question_no"] == 1
    assert blocks[0]["answer"] == 3
    assert "BCD" in blocks[0]["raw_text"]
    assert blocks[1]["question_no"] == 2
    assert blocks[1]["answer"] == 4

def test_segment_covers_all_text_no_loss():
    blocks = segment_text(FIXTURE, exam_set="A")
    joined = "".join(b["raw_text"] for b in blocks)
    assert "投資型保險與非投資型保險的最大差別" in joined
