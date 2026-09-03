from update_plain_explanations import build_update_payload


def test_draft_only_payload_omits_reviewed_flag():
    entry = {"id": 1, "plain_explanation": "白話解析內容"}
    payload = build_update_payload(entry, approve=False)
    assert payload == {"plain_explanation": "白話解析內容"}
    assert "plain_explanation_reviewed" not in payload


def test_approved_payload_sets_reviewed_true():
    entry = {"id": 1, "plain_explanation": "白話解析內容"}
    payload = build_update_payload(entry, approve=True)
    assert payload == {
        "plain_explanation": "白話解析內容",
        "plain_explanation_reviewed": True,
    }
