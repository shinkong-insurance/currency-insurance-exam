import re

_QUOTED = re.compile(r'口訣[^『\n]{0,10}『([^』]{1,30})』')
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
