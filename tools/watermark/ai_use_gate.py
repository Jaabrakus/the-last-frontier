#!/usr/bin/env python3
"""Read pixel restrictions before handing a video to a cooperating AI pipeline.

CLI exit codes: 2 = explicitly denied; 3 = permission unknown; 1 = read/error.
This opt-out reader cannot establish an affirmative license. A caller with its
own permission system can use require_action_permission() for unknown results.
Never treat an absent mark as permission, or a checksum as proof of ownership.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

import pixel_watermark as engine
from policy import permission_for_detection

ACTIONS = ("ai_use", "ai_training", "copying", "redistribution")


def evaluate_detection(detection, action="ai_use"):
    if action not in ACTIONS:
        raise ValueError("Unsupported requested action")
    permission = permission_for_detection(detection)
    denied = action in permission["restrictions"] and permission["decision"] == "deny"
    return {"schema": "pixel-use-gate/v1", "action": action,
            "decision": "deny" if denied else "unknown",
            "permission": permission,
            "asset_id": detection.get("recovered_asset_id"),
            "input_sha256": detection.get("input_sha256"),
            "reason": "The pixel policy prohibits this action." if denied else
                      "This reader has not established permission for this action."}


class UseDenied(PermissionError):
    def __init__(self, result):
        self.result = result
        super().__init__(result["reason"])


class PermissionUnknown(PermissionError):
    def __init__(self, result):
        self.result = result
        super().__init__(result["reason"])


def require_action_permission(detection, action="ai_use", *, independently_authorized=False):
    """Gate a subsequent operation, using a fresh trusted detector result.

    independently_authorized must come from the application's separate permission
    system. Missing pixels, a supplied name, or a notice are not authorization.
    An explicit deny is rejected even when this argument is true. Use the same
    checked bytes for the subsequent operation; do not substitute another input.
    """
    result = evaluate_detection(detection, action)
    if result["decision"] == "deny":
        raise UseDenied(result)
    if independently_authorized is not True:
        raise PermissionUnknown(result)
    return {**result, "decision": "allow", "authorization_source": "callers_separate_permission_system"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--use", choices=ACTIONS, default="ai_use")
    parser.add_argument("--report")
    local_model = Path(__file__).resolve().parents[2] / "services/watermark/.model/y_256b_img.jit"
    parser.add_argument("--model", default=os.environ.get("VIDEOSEAL_MODEL") or
                        str(local_model if local_model.is_file() else engine.DEFAULT_MODEL))
    parser.add_argument("--device", choices=("auto", "cpu", "cuda", "mps"), default="auto")
    args = parser.parse_args()
    try:
        if args.report:
            engine.require(Path(args.input).resolve() != Path(args.report).resolve(), "Refusing source overwrite")
            engine.require(not Path(args.report).exists(), "Refusing existing report")
        detector_args = argparse.Namespace(model=args.model, device=args.device, asset_id=None, policy_flags=None)
        detection = engine.detect(args.input, detector_args)
        result = evaluate_detection(detection, args.use)
        if args.report:
            engine.write_json(args.report, result)
        print(json.dumps(result, ensure_ascii=False))
        return 2 if result["decision"] == "deny" else 3
    except Exception as error:
        print("ai_use_gate: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
