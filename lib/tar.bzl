"""General-purpose rule to create tar archives.

Unlike [pkg_tar from rules_pkg](https://github.com/bazelbuild/rules_pkg/blob/main/docs/latest.md#pkg_tar)
this:

- Does not depend on any Python interpreter setup
- The "manifest" specification is a mature public API and uses a compact tabular format, fixing
  https://github.com/bazelbuild/rules_pkg/pull/238
- Does not have any custom program to produce the output, instead
  we rely on a well-known C++ program called "tar".
  Specifically, we use the BSD variant of tar since it provides a means
  of controlling mtimes, uid, symlinks, etc.

We also provide full control for tar'ring binaries including their runfiles.

## Modifying metadata

The `mtree_spec` rule can be used to create an mtree manifest for the tar file.
Then you can mutate that spec, as it's just a simple text file, and feed the result
as the `mtree` attribute of the `tar` rule.

For example, to set the `uid` property, you could:

```starlark
mtree_spec(
    name = "mtree",
    srcs = ["//some:files"],
)

genrule(
    name = "change_owner",
    srcs = ["mtree"],
    outs = ["mtree.mutated"],
    cmd = "sed 's/uid=0/uid=1000/' <$< >$@",
)

tar(
    name = "tar",
    srcs = ["//some:files"],
    mtree = "change_owner",
)
```

Note: We intend to contribute mutation features to https://github.com/vbatts/go-mtree
to provide a richer API for things like `strip_prefix`.
In the meantime, see the `lib/tests/tar/BUILD.bazel` file in this repo for examples.

TODO:
- Provide convenience for rules_pkg users to re-use or replace pkg_files trees
"""

load("@bazel_skylib//lib:types.bzl", "types")
load("//lib:expand_template.bzl", "expand_template")
load("//lib:utils.bzl", "propagate_common_rule_attributes")
load("//lib/private:tar.bzl", _tar = "tar", _tar_lib = "tar_lib")

mtree_spec = rule(
    doc = "Create an mtree specification to map a directory hierarchy. See https://man.freebsd.org/cgi/man.cgi?mtree(8)",
    implementation = _tar_lib.mtree_implementation,
    attrs = _tar_lib.mtree_attrs,
    toolchains = ["@aspect_bazel_lib//lib:jq_toolchain_type"],
)

tar_rule = _tar

tar_lib = _tar_lib

def tar(name, mtree = "auto", stamp = 0, **kwargs):
    """Wrapper macro around [`tar_rule`](#tar_rule).

    ### Options for mtree

    mtree provides the "specification" or manifest of a tar file.
    See https://man.freebsd.org/cgi/man.cgi?mtree(8)
    Because BSD tar doesn't have a flag to set modification times to a constant,
    we must always supply an mtree input to get reproducible builds.
    See https://reproducible-builds.org/docs/archives/ for more explanation.

    1. By default, mtree is "auto" which causes the macro to create an `mtree_spec` rule.

    2. `mtree` may be supplied as an array literal of lines, e.g.

    ```
    mtree =[
        "usr/bin uid=0 gid=0 mode=0755 type=dir",
        "usr/bin/ls uid=0 gid=0 mode=0755 time=0 type=file content={}/a".format(package_name()),
    ],
    ```

    For the format of a line, see "There are four types of lines in a specification" on the man page for BSD mtree,
    https://man.freebsd.org/cgi/man.cgi?mtree(8)

    3. `mtree` may be a label of a file containing the specification lines.

    Args:
        name: name of resulting `tar_rule`
        mtree: "auto", or an array of specification lines, or a label of a file that contains the lines.
            Subject to [$(location)](https://bazel.build/reference/be/make-variables#predefined_label_variables)
            and ["Make variable"](https://bazel.build/reference/be/make-variables) substitution.
        stamp: should mtree attribute be stamped
        **kwargs: additional named parameters to pass to `tar_rule`
    """
    mtree_target = "_{}.mtree".format(name)
    if mtree == "auto":
        mtree_spec(
            name = mtree_target,
            srcs = kwargs.get("srcs", []),
            out = "{}.txt".format(mtree_target),
            **propagate_common_rule_attributes(kwargs)
        )
    elif types.is_list(mtree):
        expand_template(
            name = mtree_target,
            out = "{}.txt".format(mtree_target),
            data = kwargs.get("srcs", []),
            # Ensure there's a trailing newline, as bsdtar will ignore a last line without one
            template = ["#mtree", "{content}", ""],
            substitutions = {
                # expand_template only expands strings in "substitions" dict. Here
                # we expand mtree and then replace the template with expanded mtree.
                "{content}": "\n".join(mtree),
            },
            stamp = stamp,
            **propagate_common_rule_attributes(kwargs)
        )
    else:
        mtree_target = mtree

    tar_rule(
        name = name,
        mtree = mtree_target,
        **kwargs
    )
