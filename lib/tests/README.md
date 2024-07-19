## Running bazel-lib tests

A test wrapper is available that runs all the permutations of runfiles:

```
cd <workspace_dir>
lib/tests/test.sh //lib/tests/...
```

This runs the following:
```
cd <workspace_dir>
1. bazel test //lib/tests/... --enable_runfiles
2. bazel test //lib/tests/... --noenable_runfiles
3. lib/tests/test_with_run.sh //lib/tests/... --enable_runfiles
4. lib/tests/test_with_run.sh //lib/tests/... --noenable_runfiles
```

These four commands each give a different set of results. `bazel run` behaves differently 
to `bazel test` in how it sets up the environment, so commands 3 and 4 give a more accurate 
validation of tools used in this way.

Note: On linux, commands 1 and 2 currently have the same behaviour (the --noenable_runfiles 
flag appears to be ignored with bazel test), I have an issue requesting clarification.

### bash scripts

#### !This script makes changes to the source tree!
WARNING: test_with_run.sh causes data to be written to the source tree. The outputs don't appear to conflict in this repo. This is discussed here: https://github.com/bazelbuild/bazel/issues/3325. I've tried --run_under and can't get it to work on windows. 

test.sh uses git to undo changes between each test run.

#### Exit code
- test_with_run.sh returns 1 if there are any failures and 0 if all tests pass
- test.sh does not have an exit code

### windows wrappers
On windows, there are bat wrappers. %BAZEL_SH% must be set to bash

- run all the permutations: `lib\tests\test.bat //lib/tests/...`
- or a single run: `lib\tests\test_with_run.bat //lib/tests/... --enable_runfiles`
