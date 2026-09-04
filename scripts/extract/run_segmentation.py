import json
import pdfplumber
from pathlib import Path
from segment_questions import parse_table_row, detect_exam_set

PDF = Path.home() / "Documents/外幣/外幣題庫_ABCDE卷整理(含新增)v3.pdf"
OUT = Path(__file__).parent / "output/raw_blocks.json"

def blocks_from_tables(tables, current_set=None):
    # 掃描每一列（不只 table[0]）辨識表頭：V1 版每頁都重印表頭（表頭剛好在
    # table[0]），但 v3 版改成整份表格只在每個考卷區段開頭出現一次表頭列，
    # 出現的位置在頁面中間、不一定是該頁 table 的第 0 列。只認 table[0] 或
    # 無條件跳過 table[1:] 的舊寫法，在 v3 版會把每頁第一筆真題目誤判為表頭
    # 而漏收，考卷代號也永遠不會從 A 更新到 B/C/D/E/新增。逐列掃描對兩版
    # PDF 都成立，是嚴格更通用的寫法。純函式（不碰 PDF），方便測試。
    all_blocks = []
    for table in tables:
        if not table:
            continue
        for row in table:
            detected = detect_exam_set(row)
            if detected:
                current_set = detected
                continue
            block = parse_table_row(row, current_set)
            if block:
                all_blocks.append(block)
    return all_blocks, current_set

def extract_all_blocks(pdf_path=None):
    all_blocks = []
    current_set = None
    with pdfplumber.open(str(pdf_path or PDF)) as pdf:
        for page in pdf.pages:
            page_blocks, current_set = blocks_from_tables(
                page.extract_tables(), current_set)
            all_blocks.extend(page_blocks)
    return all_blocks

if __name__ == "__main__":
    all_blocks = extract_all_blocks()
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(all_blocks, ensure_ascii=False, indent=2))
    print(f"{len(all_blocks)} blocks written to {OUT}")
    assert 200 <= len(all_blocks) <= 320, f"unexpected block count: {len(all_blocks)}"
    sets_present = {b["exam_set"] for b in all_blocks}
    assert {"A", "B", "C", "D", "E", "新增"}.issubset(sets_present), sets_present
