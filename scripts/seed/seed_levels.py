import json, os
from pathlib import Path
from supabase import create_client

def seed_levels():
    sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"])
    levels = json.loads(
        (Path(__file__).parent.parent / "extract/output/levels.json").read_text())
    sb.table("levels").upsert(levels).execute()
    return len(levels)

if __name__ == "__main__":
    n = seed_levels()
    print(f"seeded {n} levels")
