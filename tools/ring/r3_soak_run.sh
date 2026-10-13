#!/bin/zsh
# Round 3's % ring soak (smash_r3 spec §12): tests/ring/test_ring_soak.gd with rules=stock, normal bots, time scale 1, the
# 16 pairings (mirrors included) x 3 seeds, one Godot at a time through the lock wrapper; then the table
# (tools/ring/r3_soak_table.py) into <out>.md.
#   zsh tools/ring/r3_soak_run.sh <worktree> <scratchpad> <out.md> [seeds="7300 7301 7302"] [difficulty=normal]
W="$1"; S="$2"; OUT="$3"
SEED_TEXT="${4:-7300 7301 7302}"
SEEDS=(${=SEED_TEXT})
DIFF="${5:-normal}"
ELS=(earth water fire air)
LOGS=()
for a in $ELS; do
  for b in $ELS; do
    for s in $SEEDS; do
      name="r3soak_${a}_${b}_${s}"
      GODOT_TIMEOUT=420 FPS=60 zsh "$S/run_test_fps.sh" "$W" "$name" tests/ring/test_ring_soak.gd mode=ring element=$a foe=$b \
        rules=stock ts=1 difficulty=$DIFF seed=$s > /dev/null 2>&1
      LOGS+=("$S/logs/$name.log")
    done
  done
done
python3 "$W/tools/ring/r3_soak_table.py" "$OUT" $LOGS
