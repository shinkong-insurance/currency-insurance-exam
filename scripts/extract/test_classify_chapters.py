from classify_chapters import classify_page

RANGES = [
    {"chapter_id": 1, "page_start": 1, "page_end": 10},
    {"chapter_id": 2, "page_start": 11, "page_end": 20},
]

def test_classifies_page_in_range():
    assert classify_page(5, RANGES) == 1
    assert classify_page(15, RANGES) == 2

def test_returns_none_for_page_outside_all_ranges():
    assert classify_page(999, RANGES) is None
