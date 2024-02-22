"""
Test rule to create a pkg with DefaultInfo using copy_directory_bin_action
"""

load("@aspect_bazel_lib//lib/private:copy_directory.bzl", "copy_directory_bin_action")

_attrs = {
    "src": attr.label(
        mandatory = True,
        allow_single_file = True,
    ),
    "out": attr.string(mandatory = True),
    "_tool": attr.label(
        executable = True,
        cfg = "exec",
        default = "//tools/copy_directory",
    ),
}

def _pkg_impl(ctx):
    dst = ctx.actions.declare_directory(ctx.attr.out)

    copy_directory_bin_action(
        ctx,
        src = ctx.file.src,
        dst = dst,
        copy_directory_bin = ctx.executable._tool,
        hardlink = "auto",
        verbose = True,
        toolchain_type = None,
    )

    return [
        DefaultInfo(files = depset([dst])),
    ]

pkg = rule(
    implementation = _pkg_impl,
    attrs = _attrs,
    provides = [DefaultInfo],
)
