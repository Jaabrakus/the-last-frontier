#!/bin/zsh
# A two-machine ring test (RingNet, docs/tidebreak/ring_netcode.md) run as two processes here: the host, then a joiner a few
# seconds later (it waits for the host's ring and retries its join meanwhile); both results printed, exit 0 only when both pass.
#   zsh tools/net/ring_net_pair.sh [worktree] [test] [port]
#   test defaults to tests/net/test_ring_net_pair.gd; port to 24570 (two pairs at once: give each its own)
WT=${1:-${0:A:h:h:h}}
TEST=${2:-tests/net/test_ring_net_pair.gd}
PORT=${3:-24570}
LOGDIR=${TMPDIR:-/tmp}/tidebreak-scratch/logs
mkdir -p $LOGDIR
NAME=${TEST:t:r}
zsh $WT/tools/loop/godot_run.sh --headless --fixed-fps 60 --path $WT -s $TEST -- ring_net=host:$PORT name=Host \
	> $LOGDIR/${NAME}_host.log 2>&1 &
HOST=$!
sleep 4
zsh $WT/tools/loop/godot_run.sh --headless --fixed-fps 60 --path $WT -s $TEST -- ring_net=join:127.0.0.1:$PORT name=Joiner \
	> $LOGDIR/${NAME}_join.log 2>&1 &
JOIN=$!
wait $HOST
HE=$?
wait $JOIN
JE=$?
for r in host join; do
	print "== $r ($LOGDIR/${NAME}_$r.log)"
	grep -E "PASSED|FAILED|  ok|  FAIL|SCRIPT ERROR|Parse Error|RingNet:" $LOGDIR/${NAME}_$r.log | head -40
done
[[ $HE -eq 0 && $JE -eq 0 ]]
