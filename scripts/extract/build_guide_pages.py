def build_guide_pages(ranges: list) -> dict:
    chapters = {}
    for r in ranges:
        chapters[str(r["chapter_id"])] = {
            "pages": list(range(r["page_start"], r["page_end"] + 1)),
            "label": r["title"],
        }
    return {"intro": {"pages": [1, 2, 3, 4], "label": "課程引言"}, "chapters": chapters}
