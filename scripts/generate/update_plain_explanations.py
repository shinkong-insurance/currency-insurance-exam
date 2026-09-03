import argparse
import json
import os
from pathlib import Path

from supabase import create_client


def build_update_payload(entry: dict, approve: bool) -> dict:
    payload = {"plain_explanation": entry["plain_explanation"]}
    if approve:
        payload["plain_explanation_reviewed"] = True
    return payload


def update_plain_explanations(chapter: int, approve: bool) -> int:
    sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"])
    path = Path(__file__).parent / "output" / f"chapter_{chapter}_plain_explanations.json"
    entries = json.loads(path.read_text())
    for entry in entries:
        sb.table("questions").update(build_update_payload(entry, approve)).eq(
            "id", entry["id"]
        ).execute()
    return len(entries)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=(
            "Upsert one chapter's plain_explanation drafts "
            "(scripts/generate/output/chapter_<N>_plain_explanations.json) into Supabase."
        )
    )
    parser.add_argument("chapter", type=int, help="Chapter id (2-7)")
    parser.add_argument(
        "--approve",
        action="store_true",
        help=(
            "Also flip plain_explanation_reviewed=true for every row in this chapter. "
            "Only pass this after you have personally spot-checked >=20%% of this "
            "chapter's entries against scripts/generate/plain_explanation_batch.md, "
            "per the plan's Task 17 Step 3 human sign-off gate. Without this flag, "
            "the draft text is written but stays hidden from the app (Question.fromSupabaseRow "
            "only surfaces plain_explanation when the reviewed flag is already true)."
        ),
    )
    args = parser.parse_args()
    n = update_plain_explanations(args.chapter, args.approve)
    flag_msg = "reviewed=true" if args.approve else "reviewed left untouched (draft only, hidden from app)"
    print(f"updated {n} questions in chapter {args.chapter} ({flag_msg})")
