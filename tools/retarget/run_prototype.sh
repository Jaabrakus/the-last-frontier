#!/bin/sh
# Rebuilds the Actor_A -> Actor_B retarget prototype end to end (read-only on the
# source libraries; writes animations_extra/actor_a_rt_proto.{res,json} and the report).
#
#   tools/retarget/run_prototype.sh            # dump, retarget, build, test
#   RENDER=1 tools/retarget/run_prototype.sh   # also render the comparison sheets (opens a window)
#
# Env: PAP (Player_Animation_Project), GODOT (binary), WORK (scratch dir).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
FRONTIER=$(cd "$HERE/../.." && pwd)
PAP=${PAP:-$HOME/Downloads/Player_Animation_Project}
GODOT=${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}
WORK=${WORK:-$(mktemp -d)}
DOCS=$PAP/graph_analysis/melee_horse_prone
mkdir -p "$WORK" "$DOCS/img" "$FRONTIER/animations_extra"

# hard time limit for every Godot run
to() { s=$1; shift; perl -e 'alarm shift; exec @ARGV or die "exec failed"' "$s" "$@"; }

python3 "$HERE/clip_lists.py" "$HERE/prototype_clips.json" "$WORK"

echo "== 1. dump clips (Player_Animation_Project/godot_export)"
to 600 "$GODOT" --headless --path "$PAP/godot_export" -s "$HERE/dump_clips.gd" -- \
    actor=Actor_A "clips=@$WORK/clips_A.txt" "out=$WORK/A_clips.json" | grep dump_clips
to 600 "$GODOT" --headless --path "$PAP/godot_export" -s "$HERE/dump_clips.gd" -- \
    actor=Actor_B "clips=@$WORK/clips_B.txt" "out=$WORK/B_clips.json" | grep dump_clips

echo "== 2. retarget + metrics"
python3 "$HERE/retarget.py" --src "$WORK/A_clips.json" --dst "$WORK/B_clips.json" \
    --config "$HERE/prototype_clips.json" --out "$WORK/rt_out.json" \
    --report "$DOCS/retarget_report.json" --manifest "$FRONTIER/animations_extra/actor_a_rt_proto.json"

echo "== 3. build AnimationLibrary"
to 300 "$GODOT" --headless --path "$PAP/godot_export" -s "$HERE/build_library.gd" -- \
    "in=$WORK/rt_out.json" "out=$FRONTIER/animations_extra/actor_a_rt_proto.res" | grep build_library

echo "== 4. test in the game project"
to 300 "$GODOT" --headless --path "$FRONTIER" -s tests/retarget/test_retarget_library.gd | tail -1

if [ -n "$RENDER" ]; then
    echo "== 5. comparison sheets (windowed)"
    to 600 "$GODOT" --path "$PAP/godot_export" -s "$HERE/render_compare.gd" -- \
        "lib=$FRONTIER/animations_extra/actor_a_rt_proto.res" "out=$WORK/shots" "jobs=$HERE/render_jobs.json" | tail -1
    python3 "$HERE/compose_grid.py" "$WORK/shots" "$HERE/render_jobs.json" "$DOCS/img" "$DOCS/retarget_report.json"
fi
echo "work files: $WORK"
