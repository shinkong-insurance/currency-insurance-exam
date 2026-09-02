import re

_QUOTED = re.compile(r'口訣[^『]*『([^』]{2,200})』')
_BARE = re.compile(r'口訣\s*[→]?\s*([^\s。\n]{2,8})')

def _normalize_phrase(phrase: str) -> str:
    """Normalize a phrase, handling PDF multi-column formatting issues.

    In multi-column PDFs, quoted content may contain interleaved explanatory text.
    For example, a mnemonic like "週三、日一、週九九、十月" might appear as:
      Line 1: "週三、日一、週九"
      Line 2: [explanatory text about the pattern]
      Line 3: "九、十月"
    We try to reconstruct it by combining first and last non-empty lines.
    """
    # Split by lines first to detect multi-line content
    lines = phrase.split('\n')
    lines = [line.strip() for line in lines if line.strip()]

    if len(lines) > 2:
        # Multi-line content likely has explanatory text in the middle
        # Combine first and last lines (which should be mnemonic parts)
        combined = lines[0] + lines[-1]
        # If the combined version is reasonable length, use it
        if 2 <= len(combined) <= 20:
            return combined
        # Otherwise fall through to simple normalization

    # Simple normalization for normal cases
    phrase = phrase.replace('\n', ' ')
    phrase = ' '.join(phrase.split())

    # Trim if too long (more than ~30 chars indicates embedded explanation)
    if len(phrase) > 30:
        # Stop at first period if present
        if '。' in phrase:
            phrase = phrase.split('。')[0]
        # Otherwise trim at punctuation boundary
        elif '、' in phrase:
            # Find the last 、 within first 25 chars
            truncated = phrase[:25]
            last_comma = truncated.rfind('、')
            if last_comma > 3:
                phrase = phrase[:last_comma+1]
            else:
                phrase = phrase[:25]
        else:
            phrase = phrase[:25]

    return phrase

def extract_mnemonic_from_block(raw_text: str):
    if "口訣" not in raw_text:
        return None
    m = _QUOTED.search(raw_text)
    if m:
        phrase = _normalize_phrase(m.group(1))
        return {"phrase": phrase, "meaning_raw": raw_text.strip()}
    m = _BARE.search(raw_text)
    if m:
        return {"phrase": m.group(1), "meaning_raw": raw_text.strip()}
    return None
