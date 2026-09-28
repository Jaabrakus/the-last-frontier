#!/bin/sh
# Builds the Actor_A -> Actor_B production library `actor_b_from_a` end to end: every
# Actor_A clip the melee / prone / horse designs ask for (actor_b_from_a_clips.json).
# Read-only on the source libraries. Writes:
#   animations_extra/Actor_B_from_A.res     AnimationLibrary (resource_name actor_b_from_a)
#   animations_extra/Actor_B_from_A.json    manifest: provenance, usage metadata, checks
#   tests/retarget/data/actor_b_from_a_ref.json   Actor_A reference data for the Godot test
#   <PAP>/graph_analysis/melee_horse_prone/actor_b_from_a_report.json   full metrics
#
#   tools/retarget/build_actor_b_from_a.sh            # dump, retarget + checks, build, test
#   RENDER=1 tools/retarget/build_actor_b_from_a.sh   # also the comparison sheets (opens a window)
#
# Env: PAP (Player_Animation_Project), GODOT (binary), WORK (scratch dir).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
FRONTIER=$(cd "$HERE/../.." && pwd)
PAP=${PAP:-$HOME/Downloads/Player_Animation_Project}
GODOT=${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}
WORK=${WORK:-$(mktemp -d)}
DOCS=$PAP/graph_analysis/melee_horse_prone
CFG=$HERE/actor_b_from_a_clips.json
mkdir -p "$WORK" "$DOCS/img" "$FRONTIER/animations_extra" "$FRONTIER/tests/retarget/data"

# hard time limit for every Godot run
to() { s=$1; shift; perl -e 'alarm shift; exec @ARGV or die "exec failed"' "$s" "$@"; }

python3 "$HERE/clip_lists.py" "$CFG" "$WORK"

echo "== 1. dump clips (Player_Animation_Project/godot_export)"
to 900 "$GODOT" --headless --path "$PAP/godot_export" -s "$HERE/dump_clips.gd" -- \
    actor=Actor_A "clips=@$WORK/clips_A.txt" "out=$WORK/A_clips.json" | grep dump_clips
to 600 "$GODOT" --headless --path "$PAP/godot_export" -s "$HERE/dump_clips.gd" -- \
    actor=Actor_B "clips=@$WORK/clips_B.txt" "out=$WORK/B_clips.json" | grep dump_clips

echo "== 2. retarget + metrics + checks"
python3 "$HERE/retarget.py" --src "$WORK/A_clips.json" --dst "$WORK/B_clips.json" --config "$CFG" \
    --out "$WORK/rt_out.json" --report "$DOCS/actor_b_from_a_report.json" \
    --manifest "$FRONTIER/animations_extra/Actor_B_from_A.json" \
    --test-ref "$FRONTIER/tests/retarget/data/actor_b_from_a_ref.json"

echo "== 3. build AnimationLibrary"
to 300 "$GODOT" --headless --path "$PAP/godot_export" -s "$HERE/build_library.gd" -- \
    "in=$WORK/rt_out.json" "out=$FRONTIER/animations_extra/Actor_B_from_A.res" | grep build_library

echo "== 4. test in the game project"
status=0
to 900 "$GODOT" --headless --path "$FRONTIER" -s tests/retarget/test_actor_b_from_a.gd > "$WORK/test.log" 2>&1 || status=$?
grep -E "FAIL|ERROR|LIBRARY" "$WORK/test.log" | tail -40

if [ -n "$RENDER" ]; then
    echo "== 5. comparison sheets (windowed)"
    to 900 "$GODOT" --path "$PAP/godot_export" -s "$HERE/render_compare.gd" -- \
        "lib=$FRONTIER/animations_extra/Actor_B_from_A.res" lib_name=actor_b_from_a \
        "out=$WORK/shots" "jobs=$HERE/render_jobs_actor_b_from_a.json" w=1100 h=760 | tail -1
    python3 "$HERE/compose_grid.py" "$WORK/shots" "$HERE/render_jobs_actor_b_from_a.json" "$DOCS/img" \
        "$DOCS/actor_b_from_a_report.json"
fi
echo "work files: $WORK"
exit $status
