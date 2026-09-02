from __future__ import annotations


def classify_page(page: int, ranges: list) -> int | None:
    for r in ranges:
        if r["page_start"] <= page <= r["page_end"]:
            return r["chapter_id"]
    return None
