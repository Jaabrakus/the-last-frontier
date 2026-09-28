#!/bin/bash
# The systems films as they are handed out (user 2026-09-28: the start of every film "like the frontier start up load
# like that painted beautifullneesss"): every clip (make_clips.sh's <nn>_<clip>.mp4 and _tutorial.mp4) with the game's
# painted start-up splash before it (splash_intro.py), and the three parts, each one film: the splash, its clips, the
# credits.
#
#   tools/showcase/finish_films.sh <raw clips dir> <films dir> <work dir>
set -euo pipefail
cd "$(dirname "$0")/../.."
RAW="$1"; FILMS="$2"; WORK="$3"
mkdir -p "$FILMS" "$WORK"
[ -x "$WORK/video_encode" ] || swiftc -O tools/showcase/video_encode.swift -o "$WORK/video_encode" 2>/dev/null
rm -rf "$WORK/splash"
python3 tools/showcase/splash_intro.py "$WORK/splash"
"$WORK/video_encode" encode "$WORK/splash/frames" 30 "$WORK/splash.mp4" "$WORK/splash/audio.wav" > /dev/null
INTRO="$WORK/splash.mp4"
for f in "$RAW"/[0-9][0-9]_*.mp4; do
	base=$(basename "$f" .mp4)
	"$WORK/video_encode" join "$FILMS/$base.mp4" "$INTRO" "$f" | tail -1
done
REST="Textures: Poly Haven (CC0)  ·  Sounds: Kenney, kheetor, rubberduck (CC0) and public-domain recordings\nFull credits: CREDITS.md"
part() {
	local n="$1" credits="$2"
	shift 2
	local tut=() clean=()
	for c in "$@"; do
		tut+=("$(ls "$RAW"/*_"$c"_tutorial.mp4)")
		clean+=("$(ls "$RAW"/[0-9][0-9]_"$c".mp4)")
	done
	tools/showcase/combine.sh "$WORK" "$FILMS/Part${n}_how_to_play.mp4" "$INTRO" "$credits" "${tut[@]}"
	tools/showcase/combine.sh "$WORK" "$FILMS/Part${n}_systems.mp4" "$INTRO" "$credits" "${clean[@]}"
}
part 1 "Deer: Quaternius (CC0)\n$REST" torch hold_e axe throw vault barrow
part 2 "Deer: Quaternius (CC0)\n$REST" bow musket climb tree fell ride camp hunt
part 3 "Mammoth: Riley Kuhlman (CC0)  ·  Bison and great horned owl: Poly by Google (CC-BY 3.0)\n$REST" \
	forage rest wheel barricade build sky mammoth
