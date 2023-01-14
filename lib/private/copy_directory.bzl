"""Implementation of copy_directory macro and underlying rules.

This rule copies a directory to another location using Bash (on Linux/macOS) or
cmd.exe (on Windows).
"""

load(":copy_common.bzl", _COPY_EXECUTION_REQUIREMENTS = "COPY_EXECUTION_REQUIREMENTS")
load(":platform_utils.bzl", _platform_utils = "platform_utils")

def _copy_cmd(ctx, src, dst):
    # Most Windows binaries built with MSVC use a certain argument quoting
    # scheme. Bazel uses that scheme too to quote arguments. However,
    # cmd.exe uses different semantics, so Bazel's quoting is wrong here.
    # To fix that we write the command to a .bat file so no command line
    # quoting or escaping is required.
    # Put a hash of the file name into the name of the generated batch file to
    # make it unique within the package, so that users can define multiple copy_file's.
    bat = ctx.actions.declare_file("%s-%s-cmd.bat" % (ctx.label.name, hash(src.path)))

    # Flags are documented at
    # https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy
    # NB: robocopy return non-zero exit codes on success so we must exit 0 after calling it
    cmd_tmpl = "@robocopy \"{src}\" \"{dst}\" /E >NUL & @exit 0"
    mnemonic = "CopyDirectory"
    progress_message = "Copying directory %{input}"

    ctx.actions.write(
        output = bat,
        # Do not use lib/shell.bzl's shell.quote() method, because that uses
        # Bash quoting syntax, which is different from cmd.exe's syntax.
        content = cmd_tmpl.format(
            src = src.path.replace("/", "\\"),
            dst = dst.path.replace("/", "\\"),
        ),
        is_executable = True,
    )
    ctx.actions.run(
        inputs = [src],
        tools = [bat],
        outputs = [dst],
        executable = "cmd.exe",
        arguments = ["/C", bat.path.replace("/", "\\")],
        mnemonic = mnemonic,
        progress_message = progress_message,
        use_default_shell_env = True,
        execution_requirements = _COPY_EXECUTION_REQUIREMENTS,
    )

def _copy_bash(ctx, src, dst):
    cmd = "rm -Rf \"$2\" && cp -fR \"$1/\" \"$2\""
    mnemonic = "CopyDirectory"
    progress_message = "Copying directory %{input}"

    ctx.actions.run_shell(
        tools = [src],
        outputs = [dst],
        command = cmd,
        arguments = [src.path, dst.path],
        mnemonic = mnemonic,
        progress_message = progress_message,
        use_default_shell_env = True,
        execution_requirements = _COPY_EXECUTION_REQUIREMENTS,
    )

def copy_directory_action(ctx, src, dst, is_windows = None):
    """Factory function that creates an action to copy a directory from src to dst.

    This helper is used by copy_directory. It is exposed as a public API so it can be used within
    other rule implementations.

    Args:
        ctx: The rule context.
        src: The directory to make a copy of. Can be a source directory or TreeArtifact.
        dst: The directory to copy to. Must be a TreeArtifact.
        is_windows: Deprecated and unused
    """

    # TODO(2.0): remove deprecated & unused is_windows parameter
    if not src.is_source and not dst.is_directory:
        fail("src must be a source directory or TreeArtifact")
    if dst.is_source or not dst.is_directory:
        fail("dst must be a TreeArtifact")

    # Because copy actions have "local" execution requirements, we can safely assume
    # the execution is the same as the host platform and generate different actions for Windows
    # and non-Windows host platforms
    is_windows = _platform_utils.host_platform_is_windows()
    if is_windows:
        _copy_cmd(ctx, src, dst)
    else:
        _copy_bash(ctx, src, dst)

def copy_directory_bin_action(
        ctx,
        src,
        dst,
        copy_directory_bin,
        hardlink = "auto",
        verbose = False):
    """Factory function that creates an action to copy a directory from src to dst using a tool binary.

    The tool binary will typically be the `@aspect_bazel_lib//tools/copy_directory` `go_binary`
    either built from source or provided by a toolchain.

    This helper is used by the copy_directory rule. It is exposed as a public API so it can be used
    within other rule implementations.

    Args:
        ctx: The rule context.

        src: The source directory to copy.

        dst: The directory to copy to. Must be a TreeArtifact.

        copy_directory_bin: Copy to directory tool binary.

        hardlink: Controls when to use hardlinks to files instead of making copies.
            See copy_directory rule documentation for more details.

        verbose: If true, prints out verbose logs to stdout
    """
    args = [
        src.path,
        dst.path,
    ]
    if verbose:
        args.append("--verbose")

    if hardlink == "on":
        args.append("--hardlink")
    elif hardlink == "auto" and not src.is_source:
        args.append("--hardlink")

    ctx.actions.run(
        inputs = [src],
        outputs = [dst],
        executable = copy_directory_bin,
        arguments = args,
        mnemonic = "CopyDirectory",
        progress_message = "Copying directory %{input}",
        execution_requirements = _COPY_EXECUTION_REQUIREMENTS,
    )

def _copy_directory_impl(ctx):
    dst = ctx.actions.declare_directory(ctx.attr.out)
    copy_directory_action(ctx, ctx.file.src, dst)

    files = depset(direct = [dst])
    runfiles = ctx.runfiles(files = [dst])

    return [DefaultInfo(files = files, runfiles = runfiles)]

_copy_directory = rule(
    implementation = _copy_directory_impl,
    provides = [DefaultInfo],
    attrs = {
        "src": attr.label(mandatory = True, allow_single_file = True),
        # Cannot declare out as an output here, because there's no API for declaring
        # TreeArtifact outputs.
        "out": attr.string(mandatory = True),
    },
)

def copy_directory(name, src, out, **kwargs):
    """Copies a directory to another location.

    This rule uses a Bash command on Linux/macOS/non-Windows, and a cmd.exe command on Windows (no Bash is required).

    If using this rule with source directories, it is recommended that you use the
    `--host_jvm_args=-DBAZEL_TRACK_SOURCE_DIRECTORIES=1` startup option so that changes
    to files within source directories are detected. See
    https://github.com/bazelbuild/bazel/commit/c64421bc35214f0414e4f4226cc953e8c55fa0d2
    for more context.

    Args:
      name: Name of the rule.
      src: The directory to make a copy of. Can be a source directory or TreeArtifact.
      out: Path of the output directory, relative to this package.
      **kwargs: further keyword arguments, e.g. `visibility`
    """
    _copy_directory(
        name = name,
        src = src,
        out = out,
        **kwargs
    )
