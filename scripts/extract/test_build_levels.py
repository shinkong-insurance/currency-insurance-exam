from build_levels import build_levels

def test_splits_into_exactly_18_levels():
    questions = [{"id": i, "chapter_id": (i % 8) + 1} for i in range(1, 271)]
    levels = build_levels(questions, target_level_count=18)
    assert len(levels) == 18

def test_every_question_assigned_exactly_once():
    questions = [{"id": i, "chapter_id": (i % 8) + 1} for i in range(1, 271)]
    levels = build_levels(questions, target_level_count=18)
    all_ids = [qid for lvl in levels for qid in lvl["question_ids"]]
    assert sorted(all_ids) == list(range(1, 271))

def test_no_level_wildly_oversized_or_undersized():
    questions = [{"id": i, "chapter_id": (i % 8) + 1} for i in range(1, 271)]
    levels = build_levels(questions, target_level_count=18)
    sizes = [len(lvl["question_ids"]) for lvl in levels]
    assert min(sizes) >= 8
    assert max(sizes) <= 20
