def derive_keyword_hint(explanation: str, max_len: int = 40) -> str:
    """
    Derive a short keyword hint from an explanation.

    If the explanation contains an arrow (→), extract the segment containing it.
    Otherwise, truncate to max_len characters.

    Args:
        explanation: The full explanation text
        max_len: Maximum length for truncated hints (default 40)

    Returns:
        A short keyword hint
    """
    if "→" in explanation:
        # Extract the segment containing the arrow (usually between periods)
        segment = next(s for s in explanation.split("。") if "→" in s)
        return segment.strip()
    return explanation[:max_len]
