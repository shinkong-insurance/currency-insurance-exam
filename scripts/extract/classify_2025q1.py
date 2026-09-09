import json
import re
import sys
from collections import Counter

sys.stdout.reconfigure(encoding='utf-8')

BASE = "C:/Sthou/Documents/currency-insurance-exam/scripts/extract/output"

# Same patterns as classify_chapters.py (proven against the original 126-question
# corpus). Reused verbatim so classification stays consistent with existing content.
_REGULATION_PATTERNS = [
    (2, re.compile(r'保險業(?:申請)?辦理外匯業務管理辦法')),
    (3, re.compile(r'人身保險業辦理以外幣收付之非投資型人身保險業務')),
    (4, re.compile(r'管理外匯條例')),
    (5, re.compile(r'外匯收支或交易申報辦法')),
    (6, re.compile(r'投資型保險投資管理辦法')),
    (7, re.compile(r'保險業辦理國外投資管理辦法')),
]

def classify_by_content(text):
    best_id, best_pos = None, None
    for chapter_id, pattern in _REGULATION_PATTERNS:
        m = pattern.search(text)
        if m and (best_pos is None or m.start() < best_pos):
            best_id, best_pos = chapter_id, m.start()
    return best_id

# Second-pass topical fallback: the new 2025Q1 bank is organised by business
# topic, not by regulation name, so most questions deep inside a themed run
# don't re-cite the full regulation name every time (unlike the old A-E bank
# that classify_chapters.py was tuned for). These patterns catch the same six
# regulations by their distinctive subject-matter vocabulary instead of the
# literal law name. Order matters (first match wins) - more specific/narrow
# patterns are listed before broader ones within each regulation's group.
_FALLBACK_PATTERNS = [
    (6, re.compile(r'專設帳簿|全委投資型|投資型保險(?:契約|商品|投資標的|投資資產|之投資)|要保人以保險契約委任全權決定運用標的|連結之各種國內結構型商品|連結國外債券|投資型(?:人壽|年金)保險死亡給付|投資型與非投資型保險')),
    (7, re.compile(r'保險業(?:資金|投資|辦理國外投資|申請提高國外投資|經核定國外投資)|國外投資總額|國外表彰基金|對沖基金|私募(?:股權)?基金|國外資產證券化商品|保管機構|特定目的(?:之)?不動產投資事業|國外有價證券|外國(?:銀行|政府機構|地方政府)|資產管理自律規範')),
    (5, re.compile(r'申報義務人|外匯收支或交易|新[臺台]幣結匯|結購或結售|逕行辦理新[臺台]幣結匯|居住民|銀行業(?:輔導客戶申報|櫃[台臺])')),
    (4, re.compile(r'管理外匯之(?:行政主管機關|業務機關)|攜帶外幣|外匯之買賣、結存|國庫對外債務|國外輸入(?:貨品|餽贈品)|掌理外匯業務機關|外匯調度|以非法買賣外匯為常業|停止.{0,4}第7條、第13條及第17條|關閉外匯市場、停止或限制')),
    (2, re.compile(r'保險業(?:得申請)?辦理.{0,6}外匯業務|外幣收付之人身保險單為質之外幣放款|保險業辦理各項外匯業務|再保險業者.{0,10}外匯業務|外幣收付之投資型年金保險.{0,20}即期年金保險')),
    (3, re.compile(r'以外幣收付之非投資型人身保險|以外幣收付之非投資型人壽保險|以外幣收付之非投資型年金保險|以外幣收付之非投資型健康保險|客戶適合度|業務員.{0,10}特別測驗|準保戶|KYC|以歐元收付|以美元收付|以澳幣收付|人身保險業辦理以外幣收付')),
]

def classify_fallback(text):
    best_id, best_pos = None, None
    for chapter_id, pattern in _FALLBACK_PATTERNS:
        m = pattern.search(text)
        if m and (best_pos is None or m.start() < best_pos):
            best_id, best_pos = chapter_id, m.start()
    return best_id

approved = json.load(open(BASE + "/fx2025q1_approved.json", encoding='utf-8'))

for x in approved:
    if x['no'].startswith('ch1-'):
        # PDF chapter 1 "緒論" = timeline of when FX insurance business lines were
        # opened -> matches the app's currently-empty chapter 1 "外幣保險開放紀事"
        # directly; no regulation-name regex needed.
        x['app_chapter_id'] = 1
    else:
        cid = classify_by_content(x['q'])
        if cid is None:
            cid = classify_fallback(x['q'])
        x['app_chapter_id'] = cid if cid is not None else 8  # true fallback: general/other

c = Counter(x['app_chapter_id'] for x in approved)
print("Classification result by app chapter_id:", dict(sorted(c.items())))

unmatched = [x for x in approved if x['app_chapter_id'] == 8]
print(f"\nFell through to ch8 (no regulation-name match), {len(unmatched)} items:")
for x in unmatched[:30]:
    print(x['no'], '::', x['q'][:70])

json.dump(approved, open(BASE + "/fx2025q1_classified.json", "w", encoding='utf-8'), ensure_ascii=False, indent=1)
print(f"\nWrote fx2025q1_classified.json ({len(approved)} items)")
