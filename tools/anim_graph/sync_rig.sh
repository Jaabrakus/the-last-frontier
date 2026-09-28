#!/bin/bash
# Copy the Actor_B rig (animation library + character scene) from the asset project
# Player_Animation_Project/godot_export into Frontier, but only when the asset project's
# verify_bind_rest.gd passes (rest == the game's bind pose 'null-add', RESET, stamp, additive
# audit, skin check). Then runs tests/anim/test_rig.gd on Frontier; if that fails the previous
# Frontier files are restored. Prints the sha256 of both copies.   (plan WP0, section 4.4)
#
#   tools/anim_graph/sync_rig.sh [--pap <Player_Animation_Project>] [--dry-run]
#                                [--graph <actor_b_graph.json>] [--body <body.glb>]
#
#   --dry-run   verify and test only; copy nothing.
#   --graph     graph file for the enforced additive audit (default: Frontier's
#               animations/actor_b_graph.json when it exists; report-only audit otherwise).
#   --body      skinned body glb for the skin check (default: Frontier's
#               assets/character/actor_b_body.glb when it exists).
# Env: GODOT (binary), GODOT_TIMEOUT (seconds per Godot run, default 600).
#
# Rebuild order (see godot_export/README.md): export_all.sh -> Godot --import ->
# build_libraries.gd -> verify_bind_rest.gd -> this script.
#
# Provenance: this script copies the files, then drops the source_attribution metadata from
# Actor_B.res (strip_source_meta.gd); native_asset_id and the other metadata travel with them.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
FR="$(cd "$HERE/../.." && pwd)"
PAP="${PAP:-$HOME/Downloads/Player_Animation_Project}"
GODOT="${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
TIMEOUT="${GODOT_TIMEOUT:-600}"
DRY=0
GRAPH=""
BODY=""
while [ $# -gt 0 ]; do
	case "$1" in
		--pap) PAP="$2"; shift 2 ;;
		--dry-run) DRY=1; shift ;;
		--graph) GRAPH="$2"; shift 2 ;;
		--body) BODY="$2"; shift 2 ;;
		-h|--help) sed -n '2,24p' "$0"; exit 0 ;;
		*) echo "sync_rig: unknown argument $1" >&2; exit 2 ;;
	esac
done
GE="$PAP/godot_export"
FILES="animations/Actor_B.res characters/Actor_B.tscn"
for f in $FILES; do
	[ -f "$GE/$f" ] || { echo "sync_rig: missing $GE/$f" >&2; exit 2; }
done
[ -x "$GODOT" ] || { echo "sync_rig: Godot not found at $GODOT (set GODOT)" >&2; exit 2; }
[ -z "$GRAPH" ] && [ -f "$FR/animations/actor_b_graph.json" ] && GRAPH="$FR/animations/actor_b_graph.json"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/sync_rig.XXXXXX")"

# run_godot <log> <args...>: Godot under a hard time limit (a script error in a SceneTree
# script can leave Godot running forever). Returns Godot's exit code (137 when killed).
run_godot() {
	local log="$1"; shift
	"$GODOT" "$@" >"$log" 2>&1 &
	local pid=$!
	( sleep "$TIMEOUT"; kill -9 "$pid" 2>/dev/null && echo "sync_rig: Godot killed after ${TIMEOUT}s" >&2 ) >/dev/null 2>&1 &
	local watch=$!
	wait "$pid"
	local rc=$?
	pkill -P "$watch" 2>/dev/null
	kill "$watch" 2>/dev/null
	wait "$watch" 2>/dev/null
	return $rc
}

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

echo "== 1/3 verify_bind_rest.gd on $GE"
VARGS=("frontier=$FR")
[ -n "$GRAPH" ] && VARGS+=("graph=$GRAPH")
[ -n "$BODY" ] && VARGS+=("body=$BODY")
run_godot "$WORK/verify.log" --headless --path "$GE" -s tools/verify_bind_rest.gd -- "${VARGS[@]}"
VRC=$?
grep -v '^$' "$WORK/verify.log" | grep -v '^Godot Engine'
if [ $VRC -ne 0 ] || ! grep -q '^BIND REST OK' "$WORK/verify.log"; then
	echo "sync_rig: REFUSED -- verify_bind_rest.gd failed (exit $VRC); Frontier's rig was not touched."
	exit 1
fi

echo "== 2/3 copy"
CHANGED=0
BACKUP="$WORK/backup"
mkdir -p "$BACKUP/animations" "$BACKUP/characters"
for f in $FILES; do
	if [ -f "$FR/$f" ] && [ "$(sha "$GE/$f")" = "$(sha "$FR/$f")" ]; then
		echo "  $f: unchanged"
		continue
	fi
	CHANGED=1
	if [ $DRY -eq 1 ]; then
		echo "  $f: differs (dry run, not copied)"
		continue
	fi
	[ -f "$FR/$f" ] && cp -p "$FR/$f" "$BACKUP/$f"
	cp -p "$GE/$f" "$FR/$f.sync_tmp" && mv -f "$FR/$f.sync_tmp" "$FR/$f" || { echo "sync_rig: copying $f failed" >&2; exit 1; }
	echo "  $f: copied"
done
if [ $DRY -eq 0 ] && [ $CHANGED -eq 1 ]; then
	run_godot "$WORK/strip.log" --headless --path "$FR" -s tools/anim_graph/strip_source_meta.gd -- "$FR/animations/Actor_B.res"
	SRC=$?
	grep '^STRIP SOURCE META' "$WORK/strip.log" | sed 's/^/  /'
	if [ $SRC -ne 0 ]; then
		for f in $FILES; do
			[ -f "$BACKUP/$f" ] && cp -p "$BACKUP/$f" "$FR/$f"
		done
		echo "sync_rig: strip_source_meta.gd FAILED (exit $SRC); restored the previous Frontier rig."
		exit 1
	fi
fi

echo "== 3/3 tests/anim/test_rig.gd on $FR"
cat >"$WORK/run_test_rig.gd" <<'EOF'
extends SceneTree
func _initialize() -> void:
	var code: int = await load("res://tests/anim/test_rig.gd").standalone(self)
	quit(code)
EOF
TARGS=("--no-capture")
[ -n "$GRAPH" ] && TARGS+=("graph=$GRAPH")
[ -n "$BODY" ] && TARGS+=("body=$BODY")
run_godot "$WORK/test_rig.log" --headless --path "$FR" -s "$WORK/run_test_rig.gd" -- "${TARGS[@]}"
TRC=$?
grep -v '^$' "$WORK/test_rig.log" | grep -v '^Godot Engine'
if [ $TRC -ne 0 ] || ! grep -q '^TEST_RIG PASSED' "$WORK/test_rig.log"; then
	if [ $DRY -eq 0 ] && [ $CHANGED -eq 1 ]; then
		for f in $FILES; do
			[ -f "$BACKUP/$f" ] && cp -p "$BACKUP/$f" "$FR/$f"
		done
		echo "sync_rig: test_rig.gd FAILED (exit $TRC); restored the previous Frontier rig."
	else
		echo "sync_rig: test_rig.gd FAILED (exit $TRC)."
	fi
	exit 1
fi

echo "== sha256"
for f in $FILES; do
	echo "  $(sha "$GE/$f")  $GE/$f"
	echo "  $(sha "$FR/$f")  $FR/$f"
done
if [ $DRY -eq 0 ] && [ $CHANGED -eq 1 ]; then
	echo "  previous Frontier files: $BACKUP"
else
	rm -rf "$WORK"
fi
echo "SYNC RIG OK$([ $DRY -eq 1 ] && echo ' (dry run)')"
