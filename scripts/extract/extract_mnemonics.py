import re

_QUOTED = re.compile(r'口訣[^『]*『([^』]+)』')
_BARE = re.compile(r'口訣\s*[→]?\s*([^\s。\n]{2,8})')

def extract_mnemonic_from_block(raw_text: str):
    if "口訣" not in raw_text:
        return None
    m = _QUOTED.search(raw_text)
    if m:
        return {"phrase": m.group(1), "meaning_raw": raw_text.strip()}
    m = _BARE.search(raw_text)
    if m:
        return {"phrase": m.group(1), "meaning_raw": raw_text.strip()}
    return None
