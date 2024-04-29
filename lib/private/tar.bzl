"Implementation of tar rule"

load("//lib:paths.bzl", "to_repository_relative_path")

TAR_TOOLCHAIN_TYPE = "@aspect_bazel_lib//lib:tar_toolchain_type"

# https://www.gnu.org/software/tar/manual/html_section/Compression.html
_ACCEPTED_EXTENSIONS = [
    ".tar",  # uncompressed,
    ".gz",  # gzip
    ".tgz",  # gzip
    ".taz",  # gzip
    ".Z",  # compress
    ".taZ",  # compress
    ".bz2",  # bzip2
    ".tz2",  # bzip2
    ".tbz2",  # bzip2
    ".tbz",  # bzip2
    ".lz",  # lzip
    ".lzma",  # lzma
    ".tlz",  # lzma
    ".lzo",  # lzop
    ".xz",  # xz
    ".zst",  # zstd
    ".tzst",  # zstd
]

_COMPRESSION_TO_EXTENSION = {
    "bzip2": ".tar.bz2",
    "compress": ".tar.Z",
    "gzip": ".tar.gz",
    "lrzip": ".tar.lrz",
    "lz4": ".tar.lz4",
    "lzma": ".tar.lzma",
    "lzop": ".tar.lzo",
    "xz": ".tar.xz",
    "zstd": ".tar.zst",
}

# https://www.gnu.org/software/tar/manual/html_section/Compression.html
_ACCEPTED_COMPRESSION_TYPES = _COMPRESSION_TO_EXTENSION.keys()

_tar_attrs = {
    "args": attr.string_list(
        doc = "Additional flags permitted by BSD tar; see the man page.",
    ),
    "srcs": attr.label_list(
        doc = """\
        Files, directories, or other targets whose default outputs are placed into the tar.

        If any of the srcs are binaries with runfiles, those are copied into the resulting tar as well.
        """,
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
        values = _ACCEPTED_COMPRESSION_TYPES,
    ),
}

_mtree_attrs = {
    "srcs": attr.label_list(doc = "Files that are placed into the tar", allow_files = True),
    "out": attr.output(doc = "Resulting specification file to write"),
}

def _add_compression_args(compress, args):
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
    bsdtar = ctx.toolchains[TAR_TOOLCHAIN_TYPE]
    inputs = ctx.files.srcs[:]
    args = ctx.actions.args()

    # Set mode
    args.add(ctx.attr.mode, format = "--%s")

    # User-provided args first
    args.add_all(ctx.attr.args)

    # Compression args
    _add_compression_args(ctx.attr.compress, args)

    ext = _COMPRESSION_TO_EXTENSION[ctx.attr.compress] if ctx.attr.compress else ".tar"

    out = ctx.outputs.out or ctx.actions.declare_file(ctx.attr.name + ext)
    args.add("--file", out)

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

def _mtree_line(file, type, content = None, uid = "0", gid = "0", time = "1672560000", mode = "0755"):
    return json.encode(struct(
        file = file,
        uid = uid,
        gid = gid,
        time = time,
        mode = mode,
        type = type,
        content = content,
    ))

# This function exactly same as the one from "@aspect_bazel_lib//lib:paths.bzl"
# except that it takes workspace_name directly instead of the ctx object.
# Reason is the performance of Args.add_all closures where we use this function.
# https://bazel.build/rules/lib/builtins/Args#add_all `allow_closure` explains this.
def _to_rlocation_path(file, workspace):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    else:
        return workspace + "/" + file.short_path

def _expand(file, expander, transform = to_repository_relative_path):
    expanded = expander.expand(file)
    lines = []
    for e in expanded:
        path = transform(e)
        segments = path.split("/")
        for i in range(1, len(segments)):
            parent = "/".join(segments[:i])
            lines.append(_mtree_line(parent, "dir"))

        lines.append(_mtree_line(path, "file", content = e.path))
    return lines

def _mtree_impl(ctx):
    out = ctx.outputs.out or ctx.actions.declare_file(ctx.attr.name + ".spec")
    json_out = ctx.actions.declare_file(out.basename + ".json", sibling = out)

    content = ctx.actions.args()
    content.set_param_file_format("multiline")
    content.add_all(
        ctx.files.srcs,
        map_each = _expand,
        expand_directories = True,
        uniquify = True,
    )

    for s in ctx.attr.srcs:
        default_info = s[DefaultInfo]
        if not default_info.files_to_run.runfiles_manifest:
            continue

        runfiles_dir = _calculate_runfiles_dir(default_info)

        # copy workspace name here just in case to prevent ctx
        # to be transferred to execution phase.
        workspace_name = str(ctx.workspace_name)

        content.add(_mtree_line(runfiles_dir, type = "dir"))
        content.add_all(
            s.default_runfiles.files,
            expand_directories = True,
            uniquify = True,
            format_each = "{}/%s".format(runfiles_dir),
            # be careful about what you pass to _expand_for_runfiles as it will carry the data structures over to execution phase.
            map_each = lambda f, e: _expand(f, e, lambda f: _to_rlocation_path(f, workspace_name)),
            allow_closure = True,
        )

    ctx.actions.write(json_out, content = content)

    jq_bin = ctx.toolchains["@aspect_bazel_lib//lib:jq_toolchain_type"].jqinfo.bin

    ctx.actions.run_shell(
        tools = [jq_bin],
        inputs = [json_out],
        outputs = [out],
        command = """
while IFS= read -r jsonl; do
    file=$({jq} -r '.file' <<< "$jsonl")
    gid=$({jq} -r '.gid' <<< "$jsonl")
    uid=$({jq} -r '.uid' <<< "$jsonl")
    time=$({jq} -r '.time' <<< "$jsonl")
    mode=$({jq} -r '.mode' <<< "$jsonl")
    type=$({jq} -r '.type' <<< "$jsonl")
    content=$({jq} -r '.content' <<< "$jsonl")

    file_encoded=$(echo -n "$file" | vis -wo)
    mtree_line="$file_encoded uid=$uid gid=$gid time=$time mode=$mode type=$type"
    if [ "$content" != "null" ]; then
        content_encoded=$(echo -n "$content" | vis -wo)
        mtree_line="$mtree_line content=$content_encoded"
    fi

    echo "$mtree_line" >> {output}
done < {input}
""".format(
            jq = jq_bin.path,
            input = json_out.path,
            output = out.path,
        ),
        mnemonic = "MtreeSpec",
    )

    return DefaultInfo(files = depset([out]), runfiles = ctx.runfiles([out]))

tar_lib = struct(
    attrs = _tar_attrs,
    implementation = _tar_impl,
    mtree_attrs = _mtree_attrs,
    mtree_implementation = _mtree_impl,
    toolchain_type = TAR_TOOLCHAIN_TYPE,
    common = struct(
        accepted_tar_extensions = _ACCEPTED_EXTENSIONS,
        accepted_compression_types = _ACCEPTED_COMPRESSION_TYPES,
        compression_to_extension = _COMPRESSION_TO_EXTENSION,
        add_compression_args = _add_compression_args,
    ),
)

tar = rule(
    doc = "Rule that executes BSD `tar`. Most users should use the [`tar`](#tar) macro, rather than load this directly.",
    implementation = tar_lib.implementation,
    attrs = tar_lib.attrs,
    toolchains = [tar_lib.toolchain_type],
)
