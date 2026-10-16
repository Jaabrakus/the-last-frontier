#!/bin/zsh
# Tidebreak's web build (the Web Public preset), from this checkout through a snapshot of it:
#   zsh tools/web/build_web.sh [<snapshot dir> <out dir>]
# The snapshot and the build live by default in ~/Library/Caches/Tidebreak (web_snapshot, webbuild): kept through a restart
# (the owner, 2026-10-14: the temp folder a restart empties cost a ~25 min prep; "can we do it faster"), so a build redoes only
# what changed (1-3 min).
# 1. the snapshot made like this checkout's tracked files, never its Spellbreak extracts, artifacts or services. A first run
#    clones them (APFS copy-on-write, `cp -c`: instant, no disk until a file changes) and clones this checkout's import cache
#    (.godot/imported, with the editor's file cache of each .import's md5) with them, so the re-import redoes only what the
#    web prep changes; then rsync keeps it in step. The
#    animation libraries the snapshot holds compressed are copied again only when this checkout's file changed, or the
#    compress step did (tools/web/compress_anims.gd, anim_error.gd, seam_clips.txt: its check decides which clips stay as
#    they are); tools/web/source_hashes.txt in the snapshot
# 2. tools/web/prep_snapshot.sh: the libraries compressed (each clip checked against its original), the Spellbreak effects cut
#    to the owner's picks (the Web Public preset packs assets/fx/spellbreak/: export it only through here), lighter textures, the
#    re-import; the libraries checked again by tools/web/anim_check.gd when the compress step did anything
# 3. the export (the standard 4.7.1 editor: the .NET one has no Web export), then tools/web/pack_compress.py (the pack's
#    resources deflated) and tools/web/split_pck.py (the pack in parts for Reddit's 100 MB file limit)
# Serve <out dir> and open index.html (.claude/launch.json "tidebreak-web").
set -u
HERE=${0:A:h}
ROOT=${HERE:h:h}
CACHE=$HOME/Library/Caches/Tidebreak
SNAP=${1:-$CACHE/web_snapshot}
OUT=${2:-$CACHE/webbuild}
GODOT=${GODOT:-$HOME/Applications/Godot-4.7.1.app/Contents/MacOS/Godot}
LOG=${LOG:-$OUT.logs}
mkdir -p $SNAP $OUT $LOG
[[ ${SNAP:A} != ${ROOT:A} ]] || { echo "the snapshot can't be the checkout"; exit 1 }

# 1. the snapshot
cd $ROOT
git ls-files | grep -v -E '^(Spellbreak_Reference_Extracts|artifacts|services|\.claude)/|^CLAUDE\.md$' > $LOG/tracked.txt
grep -E '^animations(_extra)?/[^/]+\.res$' $LOG/tracked.txt > $LOG/libs.txt
grep -v -x -F -f $LOG/libs.txt $LOG/tracked.txt > $LOG/sync.txt
if [[ ! -f $SNAP/project.godot ]]; then
  echo "a new snapshot: the tracked files and the import cache cloned"
  while read -r f; do
    [[ -f $f ]] || continue
    mkdir -p $SNAP/${f:h}
    cp -c -p $f $SNAP/$f 2>/dev/null || cp -p $f $SNAP/$f
  done < $LOG/sync.txt
  if [[ -d .godot/imported ]]; then
    mkdir -p $SNAP/.godot/editor
    cp -c -R -p .godot/imported $SNAP/.godot/ 2>/dev/null || cp -R -p .godot/imported $SNAP/.godot/
    # (with the editor's file cache: it holds each .import file's md5, so Godot imports again the files whose settings the
    # web prep changes (QOA sounds, lighter textures) and keeps the rest; without it a new snapshot kept the checkout's
    # heavier imports: 304 MB, not 198)
    for c in .godot/editor/filesystem_cache[0-9]*(N); do
      [[ $c == *-* ]] || cp -p $c $SNAP/.godot/editor/
    done
  fi
fi
rsync -a --checksum --files-from=$LOG/sync.txt ./ $SNAP/ || exit 1
HASHES=$SNAP/tools/web/source_hashes.txt
mkdir -p $SNAP/tools/web
touch $HASHES
PIPE=$(cat $HERE/compress_anims.gd $HERE/anim_error.gd $HERE/seam_clips.txt | git hash-object --stdin)
while read -r lib; do
  h=$(git hash-object $lib)-${PIPE[1,8]}
  if ! grep -q -x -F "$h $lib" $HASHES; then
    cp $lib $SNAP/$lib
    grep -v " $lib\$" $HASHES > $HASHES.tmp; mv $HASHES.tmp $HASHES
    echo "$h $lib" >> $HASHES
    echo "library new or changed: $lib"
  fi
done < $LOG/libs.txt

# 2. smaller
LOG=$LOG zsh $HERE/prep_snapshot.sh $SNAP || exit 1
#    and what the compress step left of the libraries checked once more against this checkout's (tools/web/anim_check.gd: the
#    compress step's own measure on the finished files, every clip sampled every 1/120 s, about 20 s), after a run that
#    compressed anything. A clip off by more than 2 degrees or 10 mm stops the build.
if find $LOG -name 'compress_*.log' -newer $LOG/tracked.txt -exec grep -l '^WEB ANIMS res' {} + 2>/dev/null | grep -q .; then
  EMPTY=$CACHE/empty_project                       # (a project of nothing: the check touches no project cache)
  mkdir -p $EMPTY
  [[ -f $EMPTY/project.godot ]] || printf 'config_version=5\n' > $EMPTY/project.godot
  n=0
  for pair in "animations_extra/ animations_extra/" "animations/Actor_B.res animations/Actor_B.res"; do
    n=$((n + 1))
    $GODOT --headless --path $EMPTY -s $HERE/anim_check.gd -- orig=$ROOT/${pair% *} web=$SNAP/${pair#* } > $LOG/anim_check_$n.log 2>&1
    code=$?
    grep -E "^(--- summary|worst bone|worst position|ANIM CHECK DONE)|^OVER " $LOG/anim_check_$n.log | cut -c1-220
    [[ $code == 0 ]] || { echo "the web build's animations are off from the originals (exit $code): $LOG/anim_check_$n.log"; exit 1 }
  done
fi

# 3. the export, compressed and split
cd $SNAP
rm -f $OUT/index.*
$GODOT --headless --path . --export-release "Web Public" $OUT/index.html > $LOG/export.log 2>&1
code=$?
[[ -f $OUT/index.pck ]] || { echo "export failed (exit $code): $LOG/export.log"; exit 1 }
python3 -I $HERE/pack_compress.py $OUT/index.pck || exit 1
python3 -I $HERE/split_pck.py $OUT || exit 1
du -ch $OUT/index.wasm $OUT/index.pck.* | tail -1
