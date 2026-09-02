from collections import defaultdict

def build_levels(questions: list, target_level_count: int = 18):
    by_chapter = defaultdict(list)
    for q in questions:
        by_chapter[q["chapter_id"]].append(q["id"])
    for ids in by_chapter.values():
        ids.sort()

    total = len(questions)
    chapter_ids = sorted(by_chapter.keys())
    raw_allocation = {
        cid: max(1, round(len(by_chapter[cid]) / total * target_level_count))
        for cid in chapter_ids
    }
    # 調整總數精準等於 target_level_count（把差額加減在題量最大的章節）
    diff = target_level_count - sum(raw_allocation.values())
    if diff != 0:
        biggest = max(chapter_ids, key=lambda c: len(by_chapter[c]))
        raw_allocation[biggest] += diff

    levels, level_id = [], 1
    for cid in chapter_ids:
        ids = by_chapter[cid]
        n_levels = raw_allocation[cid]
        # 平均切成 n_levels 份：不能用「固定 chunk_size = ceil(len/n) 再逐段切」，
        # 那樣除不盡時最後一段會偏小（例如 34 題切 4 關會變成 9,9,9,7，7 題太少）。
        # 改成餘數平均分攤到前面幾份，讓各關題數差距最多只有 1 題（例如 9,9,8,8）。
        base, remainder = divmod(len(ids), n_levels)
        chunk_sizes = [base + 1] * remainder + [base] * (n_levels - remainder)
        start = 0
        for i, size in enumerate(chunk_sizes):
            levels.append({
                "id": level_id,
                "order": level_id,
                "label": f"第{cid}章 第{i + 1}關",
                "chapter_id": cid,
                "question_ids": ids[start:start + size],
                "pass_threshold": 0.7,
            })
            start += size
            level_id += 1
    return levels
