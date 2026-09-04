import json
from build_id_registry import load_registry, update_registry, get_id


def _q(exam_set, question_no):
    return {"exam_set": exam_set, "question_no": question_no}


def test_existing_entries_never_change_even_if_new_ones_are_inserted_ahead(tmp_path):
    path = tmp_path / "registry.json"
    path.write_text(json.dumps({"A-3": 1, "A-4": 2, "新增-60": 3}))

    # A-1 sorts BEFORE A-3/A-4 and 新增-1 sorts before 新增-60, but that must
    # not renumber the already-registered entries — this is the exact bug
    # class this registry exists to prevent (enumerate() over a list that
    # gained new members in the middle would have shifted everything after).
    questions = [_q("新增", 60), _q("A", 3), _q("A", 1), _q("A", 4), _q("新增", 1)]
    registry = update_registry(questions, path=path)

    assert registry["A-3"] == 1
    assert registry["A-4"] == 2
    assert registry["新增-60"] == 3


def test_new_entries_appended_in_stable_order_regardless_of_input_order(tmp_path):
    path = tmp_path / "registry.json"
    path.write_text(json.dumps({"A-3": 1}))

    questions_order_1 = [_q("新增", 1), _q("A", 1), _q("B", 5)]
    registry_1 = update_registry(questions_order_1, path=path)

    path2 = tmp_path / "registry2.json"
    path2.write_text(json.dumps({"A-3": 1}))
    questions_order_2 = [_q("B", 5), _q("新增", 1), _q("A", 1)]
    registry_2 = update_registry(questions_order_2, path=path2)

    # same new members, different input order -> identical resulting ids
    assert registry_1 == registry_2
    # stable A -> B -> 新增 ordering among the newly-registered entries
    assert registry_1["A-1"] == 2
    assert registry_1["B-5"] == 3
    assert registry_1["新增-1"] == 4


def test_a_question_dropped_from_the_input_keeps_its_registered_id(tmp_path):
    path = tmp_path / "registry.json"
    path.write_text(json.dumps({"A-3": 1, "A-4": 2}))

    # A-4 no longer appears in this run's classified question list (e.g. a
    # future classification-rule change excludes it) -- its slot must stay
    # reserved rather than being reused, so re-adding it later wouldn't
    # collide with whatever took id 2 in the meantime.
    registry = update_registry([_q("A", 3), _q("B", 1)], path=path)
    assert registry["A-4"] == 2
    assert registry["B-1"] == 3


def test_get_id_looks_up_by_exam_set_and_question_no():
    registry = {"E-4": 118}
    assert get_id(registry, "E", 4) == 118


def test_load_registry_returns_empty_dict_when_file_missing(tmp_path):
    assert load_registry(tmp_path / "does-not-exist.json") == {}
