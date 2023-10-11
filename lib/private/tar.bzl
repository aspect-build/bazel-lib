"Implementation of tar rule"

load("@aspect_bazel_lib//lib:paths.bzl", "to_rlocation_path")

_tar_attrs = {
    "args": attr.string_list(
        doc = "Additional flags permitted by BSD tar; see the man page.",
    ),
    "srcs": attr.label_list(
        doc = """\
        Files, directories, or other targets whose default outputs are placed into the tar.

        If any of the srcs are binaries with runfiles, those are copied into the resulting tar as well.
        """,
        mandatory = True,
        allow_files = True,
    ),
    "mode": attr.string(
        doc = """A mode indicator from the following list, copied from the tar manpage:

       - create: Create a new archive containing the specified items.
       - append: Like `create`, but new entries are appended to the archive.
            Note that this only works on uncompressed archives stored in regular files.
            The -f option is required.
       - list: List  archive contents to stdout.
       - update: Like `append`, but new entries are added only if they have a
            modification date newer than the corresponding entry in the archive.
	       Note that this only works on uncompressed archives stored in
	       regular files. The -f option	is required.
       - extract: Extract to disk from the archive. If a file with the same name
	       appears more than once in the archive, each copy	 will  be  extracted,
           with  later  copies  overwriting  (replacing) earlier copies.
        """,
        values = ["create"],  # TODO: support other modes: ["append", "list", "update", "extract"]
        default = "create",
    ),
    "mtree": attr.label(
        doc = "An mtree specification file",
        allow_single_file = True,
        # Mandatory since it's the only way to set constant timestamps
        mandatory = True,
    ),
    "out": attr.output(
        doc = "Resulting tar file to write. If absent, `[name].tar` is written.",
    ),
    "compress": attr.string(
        doc = "Compress the archive file with a supported algorithm.",
        values = ["bzip2", "compress", "gzip", "lrzip", "lz4", "lzma", "lzop", "xz", "zstd"],
    ),
}

_mtree_attrs = {
    "srcs": attr.label_list(doc = "Files that are placed into the tar", mandatory = True, allow_files = True),
    "out": attr.output(doc = "Resulting specification file to write"),
}

def _add_compress_options(compress, args):
    if compress == "bzip2":
        args.add("--bzip2")
    if compress == "compress":
        args.add("--compress")
    if compress == "gzip":
        args.add("--gzip")
    if compress == "lrzip":
        args.add("--lrzip")
    if compress == "lzma":
        args.add("--lzma")
    if compress == "lz4":
        args.add("--lz4")
    if compress == "lzop":
        args.add("--lzop")
    if compress == "xz":
        args.add("--xz")
    if compress == "zstd":
        args.add("--zstd")

def _runfile_path(ctx, file, runfiles_dir):
    return "/".join([runfiles_dir, to_rlocation_path(ctx, file)])

def _calculate_runfiles_dir(default_info):
    manifest = default_info.files_to_run.runfiles_manifest

    # Newer versions of Bazel put the manifest besides the runfiles with the suffix .runfiles_manifest.
    # For example, the runfiles directory is named my_binary.runfiles then the manifest is beside the
    # runfiles directory and named my_binary.runfiles_manifest
    # Older versions of Bazel put the manifest file named MANIFEST in the runfiles directory
    # See similar logic:
    # https://github.com/aspect-build/rules_js/blob/c50bd3f797c501fb229cf9ab58e0e4fc11464a2f/js/private/bash.bzl#L63
    if manifest.short_path.endswith("_manifest") or manifest.short_path.endswith("/MANIFEST"):
        # Trim last 9 characters, as that's the length in both cases
        return manifest.short_path[:-9]
    fail("manifest path {} seems malformed".format(manifest.short_path))

def _tar_impl(ctx):
    bsdtar = ctx.toolchains["@aspect_bazel_lib//lib:tar_toolchain_type"]
    inputs = ctx.files.srcs[:]
    args = ctx.actions.args()

    # Set mode
    args.add(ctx.attr.mode, format = "--%s")

    # User-provided args first
    args.add_all(ctx.attr.args)

    # Compression args
    _add_compress_options(ctx.attr.compress, args)

    out = ctx.outputs.out or ctx.actions.declare_file(ctx.attr.name + ".tar")
    args.add("--file", out)
    args.add("--format", "gnutar")
    args.add("-vv")

    args.add(ctx.file.mtree, format = "@%s")
    inputs.append(ctx.file.mtree)

    ctx.actions.run(
        executable = bsdtar.tarinfo.binary,
        inputs = depset(direct = inputs, transitive = [bsdtar.default.files] + [
            src[DefaultInfo].default_runfiles.files
            for src in ctx.attr.srcs
        ]),
        outputs = [out],
        arguments = [args],
        mnemonic = "Tar",
    )

    return DefaultInfo(files = depset([out]), runfiles = ctx.runfiles([out]))

def _default_mtree_line(file):
    # Functions passed to map_each cannot take optional arguments.
    return _mtree_line(file.short_path, file.path, "dir" if file.is_directory else "file")

def _mtree_line(file, content, type, uid = "0", gid = "0", time = "1672560000", mode = "0755"):
    return " ".join([
        file,
        "uid=" + uid,
        "gid=" + gid,
        "time=" + time,
        "mode=" + mode,
        "type=" + type,
        # "nlink=1",
        "device=native",
        "content=" + content,
    ])

def _mtree_impl(ctx):
    out = ctx.outputs.out or ctx.actions.declare_file(ctx.attr.name + ".spec")

    content = ctx.actions.args()
    content.set_param_file_format("multiline")
    content.add_all(ctx.files.srcs, map_each = _default_mtree_line)

    for s in ctx.attr.srcs:
        default_info = s[DefaultInfo]
        if not default_info.files_to_run.runfiles_manifest:
            continue

        runfiles_dir = _calculate_runfiles_dir(default_info)
        for file in depset(transitive = [s.default_runfiles.files]).to_list():
            destination = _runfile_path(ctx, file, runfiles_dir)
            content.add(_mtree_line(destination, file.path, "file"))

    ctx.actions.write(out, content = content)

    return DefaultInfo(files = depset([out]), runfiles = ctx.runfiles([out]))

tar_lib = struct(
    attrs = _tar_attrs,
    implementation = _tar_impl,
    mtree_attrs = _mtree_attrs,
    mtree_implementation = _mtree_impl,
)

tar = rule(
    doc = "Rule that executes BSD `tar`. Most users should use the [`tar`](#tar) macro, rather than load this directly.",
    implementation = tar_lib.implementation,
    attrs = tar_lib.attrs,
    toolchains = ["@aspect_bazel_lib//lib:tar_toolchain_type"],
)
