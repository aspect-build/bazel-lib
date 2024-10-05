"Setup jq toolchain repositories and rules"

load(":repo_utils.bzl", "repo_utils")

# Platform names follow the platform naming convention in @aspect_bazel_lib//:lib/private/repo_utils.bzl
JQ_PLATFORMS = {
    "darwin_amd64": struct(
        release_platform = "macos-amd64",
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:x86_64",
        ],
    ),
    "darwin_arm64": struct(
        release_platform = "macos-arm64",
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:aarch64",
        ],
    ),
    "linux_amd64": struct(
        release_platform = "linux-amd64",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    ),
    "linux_arm64": struct(
        release_platform = "linux-arm64",
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:aarch64",
        ],
    ),
    "windows_amd64": struct(
        release_platform = "win64",
        compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
    ),
}

DEFAULT_JQ_VERSION = "1.7"

# https://github.com/stedolan/jq/releases
#
# The integrity hashes can be computed with
# shasum -b -a 384 [downloaded file] | awk '{ print $1 }' | xxd -r -p | base64
JQ_VERSIONS = {
    "1.7": {
        "linux-amd64": "sha384-4wJ15NoxFf7r1Zf5YVGUeMPx/pfWlSfMJWLFcu4fUcBFe5L4BOpF/njEK8AH58od",
        "linux-arm64": "sha384-y9BwX+RyXf2a16xwtvcjHFfIBp3K3Ukyg4GjtmxBtynD/BKNf+0tuLtZx64TTI+/",
        "macos-amd64": "sha384-N0WdpiD8zl1k9888yGxWW/dHzztOTU+RTlZrzOYJMXXUUMqjnqXq8GwnHDsC9Lk3",
        "macos-arm64": "sha384-0nnKlrEAU7NCzTM63XYkhAGGapA/IT2O2jkU+H+ZbQFu3E+XEbgw5E/+o0oHjLGf",
        "win64": "sha384-2QfBgUpi1I5KPVrKtZnPcur+Wn/iE+tZVPFKXiIPoBKTpqZKhzc/CdqjcBn+IPiy",
    },
}

def _jq_toolchains_repo_impl(rctx):
    # Expose a concrete toolchain which is the result of Bazel resolving the toolchain
    # for the execution or target platform.
    # Workaround for https://github.com/bazelbuild/bazel/issues/14009
    starlark_content = """# @generated by @aspect_bazel_lib//lib/private:jq_toolchain.bzl
load("@aspect_bazel_lib//lib:binary_toolchain.bzl", "resolved_binary_rule")

resolved_toolchain = resolved_binary_rule(toolchain_type = "@aspect_bazel_lib//lib:jq_toolchain_type", template_variable = "JQ_BIN")
resolved_binary = resolved_binary_rule(toolchain_type = "@aspect_bazel_lib//lib:jq_runtime_toolchain_type", template_variable = "JQ_BIN")
"""
    rctx.file("defs.bzl", starlark_content)

    build_content = """# @generated by @aspect_bazel_lib//lib/private:jq_toolchain.bzl
#
# These can be registered in the workspace file or passed to --extra_toolchains flag.
# By default all these toolchains are registered by the jq_register_toolchains macro
# so you don't normally need to interact with these targets.

load(":defs.bzl", "resolved_toolchain", "resolved_binary")

resolved_toolchain(name = "resolved_toolchain", visibility = ["//visibility:public"])
resolved_binary(name = "resolved_binary", visibility = ["//visibility:public"])
"""

    for [platform, meta] in JQ_PLATFORMS.items():
        build_content += """
toolchain(
    name = "{platform}_toolchain",
    exec_compatible_with = {compatible_with},
    toolchain = "@{user_repository_name}_{platform}//:jq_toolchain",
    toolchain_type = "@aspect_bazel_lib//lib:jq_toolchain_type",
)
toolchain(
    name = "{platform}_runtime_toolchain",
    target_compatible_with = {compatible_with},
    toolchain = "@{user_repository_name}_{platform}//:jq_runtime_toolchain",
    toolchain_type = "@aspect_bazel_lib//lib:jq_runtime_toolchain_type",
)
""".format(
            platform = platform,
            user_repository_name = rctx.attr.user_repository_name,
            compatible_with = meta.compatible_with,
        )

    # Base BUILD file for this repository
    rctx.file("BUILD.bazel", build_content)

jq_toolchains_repo = repository_rule(
    _jq_toolchains_repo_impl,
    doc = """Creates a repository with toolchain definitions for all known platforms
     which can be registered or selected.""",
    attrs = {
        "user_repository_name": attr.string(doc = "Base name for toolchains repository"),
    },
)

def _jq_platform_repo_impl(rctx):
    is_windows = rctx.attr.platform.startswith("windows_")
    meta = JQ_PLATFORMS[rctx.attr.platform]
    release_platform = meta.release_platform if hasattr(meta, "release_platform") else rctx.attr.platform

    url = "https://github.com/stedolan/jq/releases/download/jq-{0}/jq-{1}{2}".format(
        rctx.attr.version,
        release_platform,
        ".exe" if is_windows else "",
    )

    rctx.download(
        url = url,
        output = "jq.exe" if is_windows else "jq",
        executable = True,
        integrity = JQ_VERSIONS[rctx.attr.version][release_platform],
    )
    build_content = """# @generated by @aspect_bazel_lib//lib/private:jq_toolchain.bzl
load("@aspect_bazel_lib//lib:binary_toolchain.bzl", "binary_toolchain", "binary_runtime_toolchain")
exports_files(["{0}"])
binary_toolchain(name = "jq_toolchain", bin = "{0}", visibility = ["//visibility:public"])
binary_runtime_toolchain(name = "jq_runtime_toolchain", bin = "{0}", visibility = ["//visibility:public"])
""".format("jq.exe" if is_windows else "jq")

    # Base BUILD file for this repository
    rctx.file("BUILD.bazel", build_content)

jq_platform_repo = repository_rule(
    implementation = _jq_platform_repo_impl,
    doc = "Fetch external tools needed for jq toolchain",
    attrs = {
        "version": attr.string(mandatory = True, values = JQ_VERSIONS.keys()),
        "platform": attr.string(mandatory = True, values = JQ_PLATFORMS.keys()),
    },
)

def _jq_host_alias_repo(rctx):
    ext = ".exe" if repo_utils.is_windows(rctx) else ""

    # Base BUILD file for this repository
    rctx.file("BUILD.bazel", """# @generated by @aspect_bazel_lib//lib/private:jq_toolchain.bzl
package(default_visibility = ["//visibility:public"])
exports_files(["jq{ext}"])
""".format(
        ext = ext,
    ))

    rctx.symlink("../{name}_{platform}/jq{ext}".format(
        name = rctx.attr.name,
        platform = repo_utils.platform(rctx),
        ext = ext,
    ), "jq{ext}".format(ext = ext))

jq_host_alias_repo = repository_rule(
    _jq_host_alias_repo,
    doc = """Creates a repository with a shorter name meant for the host platform, which contains
    a BUILD.bazel file that exports symlinks to the host platform's binaries
    """,
)
