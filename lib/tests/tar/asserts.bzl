"Make shorter assertions"

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//lib:diff_test.bzl", "diff_test")

# buildifier: disable=function-docstring
def assert_tar_listing(name, actual, expected):
    actual_listing = "_{}_listing".format(name)
    expected_listing = "_{}_expected".format(name)

    native.genrule(
        name = actual_listing,
        srcs = [actual],
        testonly = True,
        outs = ["_{}.listing".format(name)],
        cmd = "$(BSDTAR_BIN) -tvf $(execpath {}) >$@".format(actual),
        toolchains = ["@bsd_tar_toolchains//:resolved_toolchain"],
    )

    write_file(
        name = expected_listing,
        testonly = True,
        out = "_{}.expected".format(name),
        content = expected + [""],
        newline = "unix",
    )

    diff_test(
        name = name,
        file1 = actual_listing,
        file2 = expected_listing,
        timeout = "short",
    )

# buildifier: disable=function-docstring
def assert_unused_listing(name, actual, expected):
    actual_listing = native.package_relative_label("_{}_actual_listing".format(name))
    actual_shortnames = native.package_relative_label("_{}_actual_shortnames".format(name))
    actual_shortnames_file = native.package_relative_label("_{}.actual_shortnames".format(name))
    expected_listing = native.package_relative_label("_{}_expected".format(name))
    expected_listing_file = native.package_relative_label("_{}.expected".format(name))

    native.filegroup(
        name = actual_listing.name,
        output_group = "_unused_inputs_file",
        srcs = [actual],
        testonly = True,
    )

    # Trim platform-specific bindir prefix from unused inputs listing. E.g.
    #     bazel-out/darwin_arm64-fastbuild/bin/lib/tests/tar/unused/info
    #     ->
    #     lib/tests/tar/unused/info
    native.genrule(
        name = actual_shortnames.name,
        srcs = [actual_listing],
        cmd = "sed 's!^bazel-out/[^/]*/bin/!!' $< >$@",
        testonly = True,
        outs = [actual_shortnames_file],
    )

    write_file(
        name = expected_listing.name,
        testonly = True,
        out = expected_listing_file,
        content = expected + [""],
        newline = "unix",
    )

    diff_test(
        name = name,
        file1 = actual_shortnames,
        file2 = expected_listing,
        timeout = "short",
    )
