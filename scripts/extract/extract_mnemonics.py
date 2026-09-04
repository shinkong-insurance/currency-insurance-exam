import re

# Quoted mnemonic pattern: 口訣『X』
# Allows newlines in capture (bound: 1-30 chars) because explanation_raw can line-wrap
# mid-phrase even though column-interleaving is fixed; newlines are stripped post-capture.
# The gap between 口訣 and 『 also allows a newline (not just non-newline chars) — real
# PDF text sometimes wraps right after 口訣, before the opening quote (e.g. "口訣\n『總是』"),
# and without this the whole _QUOTED match fails, falling through to _BARE which then
# greedily eats the quote marks and next segment too, producing garbage like "總是』→『總額".
_QUOTED = re.compile(r'口訣[^『]{0,10}『([^』]{1,30})』')

# Bare mnemonic pattern: 口訣X or 口訣→X (direct or arrow-separated)
_BARE = re.compile(r'口訣\s*[→]?\s*([^\s。\n]{2,8})')

def extract_mnemonic_from_block(explanation_raw: str):
    if "口訣" not in explanation_raw:
        return None
    m = _QUOTED.search(explanation_raw)
    if m:
        phrase = m.group(1).replace('\n', '').strip()
        return {"phrase": phrase, "meaning_raw": explanation_raw.strip()}
    m = _BARE.search(explanation_raw)
    if m:
        phrase = m.group(1)
        # For bare style, if it accidentally captured a quote mark at start, remove it
        if phrase.startswith('『'):
            phrase = phrase[1:]
        return {"phrase": phrase, "meaning_raw": explanation_raw.strip()}
    return None
