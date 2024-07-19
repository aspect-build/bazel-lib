#!/usr/bin/env bash
target=${1}

env=$(printenv | grep -E "^(RUNFILES|BUILD|TEST)_.*=")
if [ "$env" != "" ]; then
    echo "WARNING: bazel env set outside this test harness:"
    echo "${env[@]}"
fi
diffs=$(git diff --name-only lib/tests)
if [ "$diffs" != "" ]; then
    echo "WARNING: changes to test source tree prior to running tests:"
    echo "${diffs[@]}"
    echo commit or run 'git checkout lib/tests/*' to discard
fi

tests=$(eval "bazel query 'kind(\".*_test\", ${target} ${@:2})'" | tr -d '\r')

failures=0
runs=0
passes=0
skips=0
quiet_opts="--noshow_progress --ui_event_filters=,+error,+fail --show_result=0 --logging=0"
test_opts="--skip_incompatible_explicit_targets"

echo "running each target with:"
echo "bazel run <target> $quiet_opts $test_opts $run_opts ${@:2}"
for test in ${tests}
do
    runs=$((runs + 1))
    #echo "bazel run $test $quiet_opts $test_opts $run_opts ${@:2}"
    out=$(bazel run $test $quiet_opts $test_opts $run_opts ${@:2} 2>&1)
    status=$?
    if [[ $status != 0 ]]; then
        if [[ " ${out[@]} " =~ "ERROR: No targets found to run" ]]; then
            skips=$((++skips))
            echo $test: skipped
        else
            failures=$((failures+1))
            echo "${out[@]}"
            echo -----------------------------------------------------------------------------
            echo $test: fail $status
       fi
    else
        #echo $test: pass
        passes=$((++passes))
    fi
done

echo "Executed $((runs-skips)) out of $runs tests: $passes tests pass, $failures fail and $skips were skipped."
if [[ $failures == 0 ]]; then
    exit 0
else
    exit 1
fi
