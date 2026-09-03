from build_guide_pages import build_guide_pages


def test_builds_page_ranges_keyed_by_chapter():
    ranges = [
        {"chapter_id": 1, "title": "外幣保險開放紀事", "page_start": 5, "page_end": 8},
        {"chapter_id": 2, "title": "保險業辦理外匯業務管理辦法", "page_start": 9, "page_end": 15},
    ]
    result = build_guide_pages(ranges)
    assert result["chapters"]["1"]["pages"] == [5, 6, 7, 8]
    assert result["chapters"]["1"]["label"] == "外幣保險開放紀事"
    assert result["chapters"]["2"]["pages"] == [9, 10, 11, 12, 13, 14, 15]
