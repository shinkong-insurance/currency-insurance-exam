from run_segmentation import blocks_from_tables

def test_header_repeated_at_top_of_every_page_table():
    # V1 版佈局：每頁的 table[0] 都是表頭
    tables = [
        [["題號", "答案", "A卷", "答案說明"], ["1", "2", "q1", "e1"]],
        [["題號", "答案", "A卷", "答案說明"], ["2", "3", "q2", "e2"]],
    ]
    blocks, final_set = blocks_from_tables(tables)
    assert [b["question_no"] for b in blocks] == [1, 2]
    assert all(b["exam_set"] == "A" for b in blocks)
    assert final_set == "A"

def test_header_only_once_mid_table_v3_layout():
    # v3 版佈局：表頭只在該考卷區段開頭出現一次，且不一定在 table 的第 0 列，
    # 表頭前後的題目列都要被正確收進去。
    tables = [
        [
            ["題號", "答案", "A卷", "答案說明"],
            ["1", "1", "qA1", "eA1"],
            ["2", "2", "qA2", "eA2"],
        ],
        [
            ["3", "3", "qA3", "eA3"],  # 延續 A 卷，這頁沒有重印表頭
            ["題號", "答案", "B卷", "答案說明"],  # 表頭出現在 table 中段
            ["1", "4", "qB1", "eB1"],
        ],
    ]
    blocks, final_set = blocks_from_tables(tables)
    assert [(b["exam_set"], b["question_no"]) for b in blocks] == [
        ("A", 1), ("A", 2), ("A", 3), ("B", 1),
    ]
    assert final_set == "B"

def test_current_set_carries_across_page_boundary():
    # exam_set 狀態要能跨頁延續（不能每個 table 重新從 None 開始）
    tables_page1 = [[["題號", "答案", "C卷", "答案說明"], ["1", "1", "q1", "e1"]]]
    tables_page2 = [[["2", "2", "q2", "e2"]]]  # 沒有表頭，延續上一頁的 C
    blocks1, running_set = blocks_from_tables(tables_page1)
    blocks2, running_set = blocks_from_tables(tables_page2, running_set)
    assert blocks1[0]["exam_set"] == "C"
    assert blocks2[0]["exam_set"] == "C"
    assert blocks2[0]["question_no"] == 2
