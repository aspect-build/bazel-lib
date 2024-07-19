#!/usr/bin/env bash
set +x

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
diffs=$(git diff --name-only lib/tests)
if [ "$diffs" != "" ]; then
    echo "ERROR: changes to test source tree prior to running tests:"
    echo "${diffs[@]}"
    echo commit or run 'git checkout lib/tests/*' to discard
    exit 1
fi

mkdir test-out
quiet_opts="--noshow_progress --ui_event_filters=,+error,+fail --show_result=0 --logging=0"

bazel clean >/dev/null 2>&1
bazel test "$@" --enable_runfiles $quiet_opts > test-out/bazel_test_enable_runfiles.log 2>&1
result=$(grep -m1 -E "Executed" test-out/bazel_test_enable_runfiles.log)
echo "[test enable runfiles  ] $result"

bazel clean >/dev/null 2>&1
bazel test "$@" --noenable_runfiles $quiet_opts > test-out/bazel_test_noenable_runfiles.log 2>&1
result=$(grep -m1 -E "Executed" test-out/bazel_test_noenable_runfiles.log)
echo "[test noenable runfiles] $result"

bazel clean >/dev/null 2>&1
$SCRIPT_DIR/test_with_run.sh "$@" --enable_runfiles > test-out/bazel_run_enable_runfiles.log 2>&1
result=$(grep -m1 -E "Executed" test-out/bazel_run_enable_runfiles.log)
echo "[run enable runfiles   ] $result"
git checkout lib/tests/ >/dev/null

bazel clean >/dev/null 2>&1
$SCRIPT_DIR/test_with_run.sh "$@" --noenable_runfiles > test-out/bazel_run_noenable_runfiles.log 2>&1
result=$(grep -m1 -E "Executed" test-out/bazel_run_noenable_runfiles.log)
echo "[run noenable runfiles ] $result"
git checkout lib/tests/ >/dev/null
