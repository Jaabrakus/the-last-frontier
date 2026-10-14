#!/bin/zsh
# The web build's snapshot made smaller before its export: run on the web snapshot (a clone of the project, never the working
# project) with the standard 4.7.1 editor. Each step only changes the snapshot.
#   zsh tools/web/prep_snapshot.sh <snapshot dir>
set -u
SNAP=${1:?snapshot dir}
GODOT=${GODOT:-$HOME/Applications/Godot-4.7.1.app/Contents/MacOS/Godot}
LOG=${LOG:-/tmp/web_prep}
mkdir -p $LOG
cd $SNAP || exit 1
[[ -f project.godot && $(basename $SNAP) != Frontier ]] || { echo "not a snapshot: $SNAP"; exit 1 }
mkdir -p tools/web && cp ${0:A:h}/compress_anims.gd ${0:A:h}/shell.html tools/web/

# 1. Animations compressed (tools/web/compress_anims.gd), a batch of clips a run (exit 3: more to do); a run the system
#    kills puts its last clip on the skip list for the next. The clips known to run compress() away are kept in the repo
#    (tools/web/anim_skip.txt) and skipped from the first run: a new snapshot (a restart emptied the temp folder once)
#    no longer finds them again one killed run at a time; each new one found is added there.
SKIP=$LOG/anim_skip.txt
KNOWN=${0:A:h}/anim_skip.txt
touch $SKIP $KNOWN
sort -u $KNOWN $SKIP -o $SKIP
for run in {1..60}; do
  WEB_SNAPSHOT=1 SKIP_FILE=$SKIP $GODOT --headless --path . -s res://tools/web/compress_anims.gd > $LOG/compress_$run.log 2>&1
  code=$?
  grep "^WEB ANIMS res\|^WEB ANIMS all" $LOG/compress_$run.log
  [[ $code == 0 ]] && break
  [[ $code == 3 ]] && continue
  last=$(grep "^WEB ANIMS clip" $LOG/compress_$run.log | tail -1 | sed -E 's/^WEB ANIMS clip //')
  [[ -z $last ]] && { echo "compress failed (exit $code) before any clip"; exit 1 }
  echo "compress run $run lost on '$last' (exit $code): skipped from now on"
  echo $last >> $SKIP
done
sort -u $SKIP -o $SKIP
cmp -s $SKIP $KNOWN || { cp $SKIP $KNOWN; echo "tools/web/anim_skip.txt: $(wc -l < $KNOWN | tr -d ' ') clips known to run away (commit it)" }

# 2. The Spellbreak effects cut to the moves a public build plays (tools/web/prep_sbfx.py: the owner's moves_on picks), lighter
#    textures (tools/web/prep_imports.py), then the re-import.
python3 -I ${0:A:h}/prep_sbfx.py $SNAP || exit 1
python3 -I ${0:A:h}/prep_imports.py $SNAP || exit 1
$GODOT --headless --path . --import > $LOG/import.log 2>&1
echo "import exit $?"
