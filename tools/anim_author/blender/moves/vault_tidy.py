"""The sprint vault without the arms' flourish (user 2026-09-30: "on vaults lose the right arm flair"): the source's vault (body,
legs, the left hand's plant, the timing), with the right arm's swing after its touch on the top pulled toward the arm's own relaxed
running pose (relative to the chest): a quarter of the swing kept, eased in after the release and out before the run."""
NATIVE = "vault_sprint"
SPEC = {
    "t_a": 0.0, "dur": 1.3, "blend": 0.12, "native_body": True,
    "obstacles": [("obstacle", (-1.0, 0.0, 0.82), (1.0, 0.95, 1.25), (0.72, 0.68, 0.6))],
    "arm_calm": [
        {"side": "r", "keep": 0.25,
         "w": [(0.0, (0, 0, 0)), (0.45, (0, 0, 0)), (0.65, (1, 0, 0)), (1.08, (1, 0, 0)), (1.28, (0, 0, 0)), (1.3, (0, 0, 0))]},
        # (user 2026-09-30: "same with left arm flair on vaults"): the left hand plants until about 0.58 s, its swing calmed after the release
        {"side": "l", "keep": 0.25,
         "w": [(0.0, (0, 0, 0)), (0.58, (0, 0, 0)), (0.75, (1, 0, 0)), (1.08, (1, 0, 0)), (1.28, (0, 0, 0)), (1.3, (0, 0, 0))]},
    ],
    "keys": {},
}
