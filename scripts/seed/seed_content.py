import json, os, uuid
from pathlib import Path
from supabase import create_client
from build_id_registry import load_registry, update_registry, get_id

# mnemonic_cards.id 是 uuid_generate_v4() 隨機預設值——如果 upsert 的 payload 不帶
# id，每次重跑都會被視為全新一列（沒有可比對的衝突鍵），實際上永遠是「插入」而
# 不是「更新」，導致重跑腳本會不斷疊加重複的口訣卡。這裡改用「同一句 phrase 永遠
# 算出同一個 uuid」（uuid5 是確定性雜湊，非隨機），讓 upsert 真正能對到同一列。
_MNEMONIC_NAMESPACE = uuid.UUID("d1f9b6a0-6e4a-4e1a-9c2a-2f6b6a2a4b1e")

def mnemonic_card_id(phrase: str) -> str:
    return str(uuid.uuid5(_MNEMONIC_NAMESPACE, phrase))

def to_question_row(q: dict, id_: int) -> dict:
    return {
        "id": id_,
        "chapter_id": q["chapter_id"],
        "question_no": q["question_no"],
        "question": q["question"],
        "options": q["options"],
        "answer": q["answer"],
        "explanation": q["explanation"],
        "keyword_hint": q.get("keyword_hint"),
        "textbook_page": q.get("textbook_page"),
        "exam_set": q.get("exam_set"),
    }

def seed():
    sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"])
    ranges = json.loads((Path(__file__).parent.parent / "extract/chapter_page_ranges.json").read_text())
    sb.table("course").upsert({"id": 1, "name": "外幣保險資格測驗認證班"}).execute()
    sb.table("chapters").upsert([
        {"id": r["chapter_id"], "course_id": 1, "unit_no": r["chapter_id"], "title": r["title"], "weight": ""}
        for r in ranges
    ]).execute()

    questions = json.loads((Path(__file__).parent.parent / "extract/output/questions_with_chapter.json").read_text())
    # id 一律查穩定的 question_id_registry.json，不能用 enumerate()——分類
    # 規則之後任何調整都可能讓 questions_with_chapter.json 裡「誰在清單裡、
    # 排在第幾個」跟著變，若 id 是位置決定的，就會讓已經寫好、用 id 對應
    # 題目的 plain_explanation batch（scripts/generate/output/chapter_<N>_
    # plain_explanations.json）在下一次 seed 時悄悄套到錯的題目上，且不會
    # 有任何錯誤訊息。詳見 build_id_registry.py 開頭的說明。
    registry = update_registry(questions)
    rows = [to_question_row(q, get_id(registry, q["exam_set"], q["question_no"])) for q in questions]
    sb.table("questions").upsert(rows).execute()

    # 把這次實際指派的 id 寫回一個新檔案，Task 12 (18關切分) 依賴這個檔案取得
    # 跟 Supabase 裡完全一致的 question id，不能靠「兩支腳本各自重算 enumerate+1」
    # 這種隱性假設互相對齊 —— 那樣只要任一邊改了篩選/排序條件就會悄悄兜不起來。
    seeded = [{**q, "id": rows[i]["id"]} for i, q in enumerate(questions)]
    (Path(__file__).parent.parent / "extract/output/questions_seeded.json").write_text(
        json.dumps(seeded, ensure_ascii=False, indent=2))

    # (exam_set, question_no) -> (question db id, chapter_id)，供口訣卡與原題目正確掛勾
    lookup = {
        (q["exam_set"], q["question_no"]): (rows[i]["id"], rows[i]["chapter_id"])
        for i, q in enumerate(questions)
    }

    mnemonics = json.loads((Path(__file__).parent.parent / "extract/output/mnemonic_cards_original.json").read_text())
    mnemonic_rows, skipped = [], []
    for m in mnemonics:
        # related_question_nos 是一個 [{exam_set, question_no}, ...] 清單（同一句口訣
        # 常出現在多份考卷的相似題目，Task 5 已依 phrase 去重合併），這裡把每一個都
        # 對應回真正的 question id，缺一筆不代表整張口訣卡作廢，只跳過那一筆關聯。
        related_ids, chapter_id = [], None
        for ref in m["related_question_nos"]:
            key = (ref["exam_set"], ref["question_no"])
            if key not in lookup:
                skipped.append({**ref, "phrase": m["phrase"]})
                continue
            q_id, cid = lookup[key]
            related_ids.append(q_id)
            chapter_id = chapter_id or cid  # 用第一個對得上的題目所屬章節代表整張卡
        if not related_ids:
            continue  # 這句口訣的所有出處都對應不到已分類的題目，整張卡跳過
        mnemonic_rows.append({
            "id": mnemonic_card_id(m["phrase"]),
            "chapter_id": chapter_id,
            "phrase": m["phrase"], "meaning": [m["meaning_raw"]],
            "source": "original", "approved": True,
            "related_question_ids": related_ids,
        })
    if mnemonic_rows:
        sb.table("mnemonic_cards").upsert(mnemonic_rows).execute()
    if skipped:
        print(f"警告：{len(skipped)} 筆口訣卡的出處題目對應不到已分類的題目，需人工確認：")
        for s in skipped:
            print(f"  [{s['exam_set']}-{s['question_no']}] {s['phrase']}")
    return len(rows), len(mnemonic_rows)

if __name__ == "__main__":
    n_q, n_m = seed()
    print(f"seeded {n_q} questions, {n_m} mnemonic cards")
