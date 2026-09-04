"""維護 (exam_set, question_no) -> 穩定 question id 的對照表。

**為什麼需要這個檔案**：`seed_content.py` 過去單純用
`enumerate(questions_with_chapter.json)` 依序指派 id——這個 id 同時也是
`scripts/generate/output/chapter_<N>_plain_explanations.json` 裡每一筆
白話解析引用的 question id，而 `update_plain_explanations.py --approve`
是單純用 `.eq("id", entry["id"])` 去比對、寫回 Supabase 的 `questions` 表。

問題是：`questions_with_chapter.json` 每次重新分類（比對哪些題目對得到某個
章節的法規名稱）都可能讓「哪些題目在清單裡、清單裡的順序」跟著變——2026-09-04
放寬 ch3 分類規則、多分出 5 題以後，原本已經核對過的 114 題白話解析裡，
80 題的 `enumerate()` 位置往後移了。如果那時候已經真的 seed 過 Supabase，
`update_plain_explanations.py --approve` 就會把白話解析寫到錯的題目上，
而且不會有任何錯誤訊息——這是這份程式存在的原因：把 id 指派從「清單裡的
位置」改成「第一次被分類到時就固定下來、之後永遠不變」。

**運作方式**：`question_id_registry.json` 是一份已經 commit 進 git 的持久
對照表，key 是 `"<exam_set>-<question_no>"`，value 是該題的 question id。
每次跑這支程式：
- 已經在對照表裡的項目，id 原封不動（即使該題後來在
  `questions_with_chapter.json` 裡的位置改變了，也不影響）。
- 新出現在 `questions_with_chapter.json`、還沒被登記過的題目，依
  （考卷代號 A→B→C→D→E→新增、再依題號)的固定順序，接在目前最大 id
  後面依序指派新 id，讓每次執行的結果可重現（不依賴 dict 走訪順序或
  `questions_with_chapter.json` 本身的排列）。
- 已登記過、但這次沒出現在 `questions_with_chapter.json`（例如分類規則
  之後又變嚴格，某題被踢出分類清單）的項目：id 繼續保留在對照表裡，
  只是 `seed_content.py` 不會用到它，不影響其他項目的編號穩定性。

`seed_content.py` 應該從這份對照表查 id，不要再用 `enumerate()`。
"""

import json
from pathlib import Path

REGISTRY_PATH = Path(__file__).parent / "question_id_registry.json"

_EXAM_SET_ORDER = {"A": 0, "B": 1, "C": 2, "D": 3, "E": 4, "新增": 5}


def _sort_key(exam_set: str, question_no: int):
    return (_EXAM_SET_ORDER.get(exam_set, 99), question_no)


def load_registry(path: Path = REGISTRY_PATH) -> dict:
    if path.exists():
        return json.loads(path.read_text())
    return {}


def update_registry(questions: list[dict], path: Path = REGISTRY_PATH) -> dict:
    """回傳更新後的對照表（已寫回 path），既有項目的 id 不變。"""
    registry = load_registry(path)
    next_id = max(registry.values(), default=0) + 1

    new_keys = [
        (q["exam_set"], q["question_no"])
        for q in questions
        if f"{q['exam_set']}-{q['question_no']}" not in registry
    ]
    # 固定順序（不依賴 questions_with_chapter.json 本身的排列），讓重跑結果
    # 可重現：同一批新題目不管輸入順序為何，永遠指派到同樣的 id。
    new_keys.sort(key=lambda k: _sort_key(*k))

    for exam_set, question_no in new_keys:
        registry[f"{exam_set}-{question_no}"] = next_id
        next_id += 1

    path.write_text(json.dumps(registry, ensure_ascii=False, indent=2, sort_keys=False))
    return registry


def get_id(registry: dict, exam_set: str, question_no: int) -> int:
    return registry[f"{exam_set}-{question_no}"]


if __name__ == "__main__":
    questions_path = (
        Path(__file__).parent.parent / "extract" / "output" / "questions_with_chapter.json"
    )
    questions = json.loads(questions_path.read_text())
    before = len(load_registry())
    registry = update_registry(questions)
    after = len(registry)
    print(f"question_id_registry.json: {before} -> {after} entries "
          f"({after - before} newly registered)")
