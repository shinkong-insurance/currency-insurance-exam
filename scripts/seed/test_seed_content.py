from seed_content import to_question_row

def test_converts_structured_question_to_supabase_row():
    q = {
        "chapter_id": 2, "question_no": 5, "question": "測試題",
        "options": ["A", "B", "C", "D"], "answer": 1,
        "explanation": "解析", "keyword_hint": "提示", "textbook_page": 23,
        "exam_set": "A",
    }
    row = to_question_row(q, id_=1)
    assert row["id"] == 1
    assert row["chapter_id"] == 2
    assert row["options"] == ["A", "B", "C", "D"]
    assert row["exam_set"] == "A"
