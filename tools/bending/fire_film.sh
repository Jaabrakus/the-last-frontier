#!/bin/zsh
# Fire's films: tools/bending/fire_review.gd saves every frame of each take's recorded stretch (film=<frames dir>), this joins them
# (60 fps, H.264, no sound: the effects' own sounds are not the subject) into <out.mp4>.
#   [STILLS=<dir>] zsh tools/bending/fire_film.sh <tag> <out.mp4> [only=punch,kick ...] [view=close|wide|game] [light=noon]
# The frames go to a scratch folder and are deleted after. Godot runs through the lock (tools/loop/godot_run.sh).
set -e
cd "${0:A:h}/../.."
TAG="$1"; OUT="$2"; shift 2
FR="${TMPDIR:-/tmp}/fire_film_${TAG}_$$"
rm -rf "$FR"; mkdir -p "$FR"
ONLY=""; VIEW="close"; LIGHT="noon"
for a in "$@"; do
  case "$a" in
    only=*) ONLY="$a" ;;
    view=*) VIEW="${a#view=}" ;;
    light=*) LIGHT="$a" ;;
  esac
done
GODOT_TIMEOUT=2400 zsh tools/loop/godot_run.sh --path "$PWD" --resolution 1280x720 --fixed-fps 60 -s tools/bending/fire_review.gd -- \
  out="$FR/stills" tag="$TAG" views="$VIEW" film="$FR/frames" $ONLY $LIGHT > "$FR/log.txt" 2>&1 || true
grep -E "FIRE REVIEW|SCRIPT ERROR" "$FR/log.txt" | head -20
# STILLS=<dir>: the stills and sheets the same run took are kept there (before / after of the same frozen frames)
if [[ -n "${STILLS:-}" ]]; then mkdir -p "$STILLS"; cp "$FR"/stills/*.png "$STILLS"/ 2>/dev/null || true; fi
FF=$(python3 -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
mkdir -p "$(dirname "$OUT")"
"$FF" -y -loglevel error -framerate 60 -i "$FR/frames/f%05d.jpg" -c:v libx264 -pix_fmt yuv420p -crf 17 "$OUT"
echo "FILM $OUT ($(ls "$FR/frames" | wc -l) frames)"
rm -rf "$FR"
