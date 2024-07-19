"Helpers for making test assertions"

load("@bazel_skylib//lib:types.bzl", "types")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//lib:diff_test.bzl", "diff_test")
load("//lib:jq.bzl", "jq")
load("//lib:params_file.bzl", "params_file")
load("//lib:utils.bzl", "default_timeout")
load("//lib:paths.bzl", "BASH_RLOCATION_PREFIX")

def assert_contains(name, actual, expected, size = None, timeout = None, **kwargs):
    """Generates a test target which fails if the file doesn't contain the string.

    Depends on bash, as it creates an sh_test target.

    Args:
        name: target to create
        actual: Label of a file
        expected: a string which should appear in the file
        size: the size attribute of the test target
        timeout: the timeout attribute of the test target
        **kwargs: additional named arguments for the resulting sh_test
    """

    test_sh = "_{}_test.sh".format(name)
    expected_file = "_{}_expected.txt".format(name)

    write_file(
        name = "_%s_expected" % name,
        out = expected_file,
        content = [expected],
    )

    write_file(
        name = "_" + name,
        out = test_sh,
        content = BASH_RLOCATION_PREFIX + [
            "set -o errexit",
            "file1=$(rlocation $1)",
            "file2=$(rlocation $2)",
            "grep --fixed-strings -f $file1 $file2",
        ],
    )

    native.sh_test(
        name = name,
        srcs = [test_sh],
        args = ["$(rlocationpath %s)" % expected_file, "$(rlocationpath %s)" % actual],
        size = size,
        timeout = default_timeout(size, timeout),
        data = [actual, expected_file, "@bazel_tools//tools/bash/runfiles"],
        **kwargs
    )

def assert_outputs(name, actual, expected, **kwargs):
    """Assert that the default outputs of a target are the expected ones.

    Args:
        name: name of the resulting diff_test
        actual: string of the label to check the outputs
        expected: a list of rootpaths of expected outputs, as they would appear in a runfiles manifest
        **kwargs: additional named arguments for the resulting diff_test
    """

    if not types.is_list(expected):
        fail("expected should be a list of strings, not " + type(expected))

    params_file(
        name = "_actual_" + name,
        data = [actual],
        args = ["$(rootpaths {})".format(actual)],
        out = "_{}_outputs.txt".format(name),
    )

    write_file(
        name = "_expected_ " + name,
        content = expected,
        out = "_expected_{}.txt".format(name),
    )

    diff_test(
        name = name,
        file1 = "_expected_ " + name,
        file2 = "_actual_" + name,
        **kwargs
    )

def assert_json_matches(name, file1, file2, filter1 = ".", filter2 = ".", **kwargs):
    """Assert that the given json files have the same semantic content.

    Uses jq to filter each file. The default value of `"."` as the filter
    means to compare the whole file.

    See the [jq rule](./jq.md#jq) for more about the filter expressions as well as
    setup notes for the `jq` toolchain.

    Args:
        name: name of resulting diff_test target
        file1: a json file
        file2: another json file
        filter1: a jq filter to apply to file1
        filter2: a jq filter to apply to file2
        **kwargs: additional named arguments for the resulting diff_test
    """
    name1 = "_{}_jq1".format(name)
    name2 = "_{}_jq2".format(name)
    jq(
        name = name1,
        srcs = [file1],
        filter = filter1,
    )

    jq(
        name = name2,
        srcs = [file2],
        filter = filter2,
    )

    diff_test(
        name = name,
        file1 = name1,
        file2 = name2,
        failure_message = "'{}' from {} doesn't match '{}' from {}".format(
            filter1,
            file1,
            filter2,
            file2,
        ),
        **kwargs
    )

def assert_archive_contains(name, archive, expected, type = None, **kwargs):
    """Assert that an archive file contains at least the given file entries.

    Args:
        name: name of the resulting sh_test target
        archive: Label of the the .tar or .zip file
        expected: a (partial) file listing, either as a Label of a file containing it, or a list of strings
        type: "tar" or "zip". If None, a type will be inferred from the filename.
        **kwargs: additional named arguments for the resulting sh_test
    """

    if not type:
        if archive.endswith(".whl") or archive.endswith(".zip"):
            type = "zip"
        elif archive.endswith(".tar"):
            type = "tar"
        else:
            fail("could not infer type from {}, please set the type attribute explicitly".format(archive))
    if not type in ["tar", "zip"]:
        fail("type must be 'tar' or 'zip', not " + type)

    # Command to list the files in the archive
    command = "unzip -Z1" if type == "zip" else "tar -tf"

    # -f $actual: use this file to contain one pattern per line
    # -F: treat each pattern as a plain string, not a regex
    # -x: match whole lines only
    # -v: only print lines which don't match
    grep = "grep -F -x -v -f $actual"

    script_name = "_gen_assert_" + name
    expected_name = "_expected_" + name

    if types.is_list(expected):
        write_file(
            name = expected_name,
            out = expected_name + ".mf",
            content = expected,
        )
    else:
        expected_name = expected

    write_file(
        name = script_name,
        out = "assert_{}.sh".format(name),
        content = BASH_RLOCATION_PREFIX + [
            "actual=$(mktemp)",
            "{} $(rlocation $1) > $actual".format(command),
            "# Grep exits 1 if no matches, which is success for this test.",
            "if {} $(rlocation $2); then".format(grep),
            "  echo",
            "  echo 'ERROR: above line(s) appeared in {} but are not present in the archive' $1".format(expected_name),
            "  exit 1",
            "fi",
        ],
    )

    native.sh_test(
        name = name,
        srcs = [script_name],
        args = ["$(rlocationpath %s)" % archive, "$(rlocationpath %s)" % expected_name],
        data = [archive, expected_name, "@bazel_tools//tools/bash/runfiles"],
        timeout = "short",
        **kwargs
    )

def assert_directory_contains(name, directory, expected, **kwargs):
    """Assert that a directory contains at least the given file entries.

    Args:
        name: name of the resulting sh_test target
        directory: Label of the directory artifact
        expected: a (partial) file listing, either as a Label of a file containing it, or a list of strings
        **kwargs: additional named arguments for the resulting sh_test
    """

    # -f $actual: use this file to contain one pattern per line
    # -F: treat each pattern as a plain string, not a regex
    # -x: match whole lines only
    # -v: only print lines which don't match
    grep = "grep -F -x -v -f $actual"

    script_name = "_gen_assert_" + name
    expected_name = "_expected_" + name

    if types.is_list(expected):
        write_file(
            name = expected_name,
            out = expected_name + ".mf",
            content = expected,
        )
    else:
        expected_name = expected

    write_file(
        name = script_name,
        out = "assert_{}.sh".format(name),
        content = BASH_RLOCATION_PREFIX + [
            "actual=$(mktemp)",
            "pushd $(rlocation $1) > /dev/null",
            "find . -type l,f | cut -b 3- > $actual",
            "popd > /dev/null",
            "# Grep exits 1 if no matches, which is success for this test.",
            "if {} $(rlocation $2); then".format(grep),
            "  echo",
            "  echo 'ERROR: above line(s) appeared in {} but are not present in the directory' $1".format(expected_name),
            "  exit 1",
            "fi",
        ],
    )

    native.sh_test(
        name = name,
        srcs = [script_name],
        args = ["$(rlocationpath %s)" % directory, "$(rlocationpath %s)" % expected_name],
        data = [directory, expected_name, "@bazel_tools//tools/bash/runfiles"],
        timeout = "short",
        **kwargs
    )
