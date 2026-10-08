"""Shared permission interpretation for reports obtained from the pixel detector."""

RESTRICTIONS = {"deny_copying": "copying", "deny_redistribution": "redistribution",
                "deny_ai_training": "ai_training", "deny_ai_inference": "ai_use"}
POLICY_BITS = {"deny_copying": 1, "deny_redistribution": 8,
               "deny_ai_training": 2, "deny_ai_inference": 4}


def permission_for_detection(detection):
    """Never infer permission from notice text, an expected UUID, or absence of a denial."""
    answer = {"schema": "tidebreak-permission/v1", "decision": "unknown", "restrictions": [],
              "instruction": None, "source": "unknown"}
    if not isinstance(detection, dict) or detection.get("valid") is not True or detection.get("payload_version") != "TBW2":
        return answer
    policy = detection.get("policy")
    if not isinstance(policy, dict) or policy.get("schema") != "pixel-use-policy/v1":
        return answer
    flags = policy.get("flags")
    if type(flags) is not int or not 0 <= flags <= 15:
        return answer
    if any(type(policy.get(key)) is not bool or policy[key] != bool(flags & bit) for key, bit in POLICY_BITS.items()):
        return answer
    answer["source"] = "pixel_payload"
    denied = [name for key, name in RESTRICTIONS.items() if policy[key]]
    if flags and denied and detection.get("policy_state") == "deny":
        answer.update(decision="deny", restrictions=denied,
                      instruction=policy.get("instruction") if isinstance(policy.get("instruction"), str) else None)
    return answer
