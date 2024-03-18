"Provide access to a BSD tar"

load(":repo_utils.bzl", "repo_utils")

BSDTAR_PLATFORMS = {
    "linux_amd64": struct(
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    ),
    "linux_arm64": struct(
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
    # WARNING: host toolchain should always come last to make it a fallback toolchain.
    "host": struct(
        # loaded by the macro
        compatible_with = "HOST_CONSTRAINTS",
    ),
}

WINDOWS_DEPS = (
    "e06f10043b1b148eb38ad06cff678af05beade0bdd2edd8735a198c521fa3993",
    "https://github.com/libarchive/libarchive/releases/download/v3.7.2/libarchive-v3.7.2-amd64.zip",
)

# note, using Ubuntu Focal packages as they link with older glibc versions.
# Ubuntu Jammy packages will fail on ubuntu 20.02 with
# bsdtar: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.33' not found
# bsdtar: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found
#
# TODO: this is only a partial listing of the transitive deps of libarchive-tools
# so we expect a bunch of compress modes are broken, for example.

LINUX_LIB_DEPS = {
    "linux_arm64": [
        (
            "6d18525e248e84b8a4ee39a226fd1195ca9b9d0d5a1c7909ae4f997d46378848",
            "http://ports.ubuntu.com/pool/main/n/nettle/libnettle7_3.5.1+really3.5.1-2ubuntu0.2_arm64.deb",
        ),
        (
            "aa5e31d05a9d6bde8093137bd1c82b5a20a5f470bd5109642014f895c20f323a",
            "http://ports.ubuntu.com/pool/main/liba/libarchive/libarchive13_3.4.0-2ubuntu1_arm64.deb",
        ),
        (
            "6d089f878507b536d8ca51b1ad80a80706a1dd7dbbcce7600800d3f9f98be2ab",
            "http://ports.ubuntu.com/pool/main/liba/libarchive/libarchive-tools_3.2.1-2~ubuntu16.04.1_arm64.deb",
        ),
        (
            "6242892cb032859044ddfcfbe61bac5678a95c585d8fff4525acaf45512e3d39",
            "http://ports.ubuntu.com/pool/main/libx/libxml2/libxml2_2.9.10+dfsg-5_arm64.deb",
        ),
        (
            "6302e309ab002af30ddfa0d68de26c68f7c034ed2f45b1d97a712bff1a03999a",
            "http://ports.ubuntu.com/pool/main/i/icu/libicu66_66.1-2ubuntu2_arm64.deb",
        ),
    ],
    "linux_amd64": [
        # https://packages.ubuntu.com/focal/amd64/libarchive-tools/download
        (
            "12a19878d34b407e6f4893d3b26b7758a26c5534a066d76184c8b764b2df1652",
            "http://security.ubuntu.com/ubuntu/pool/universe/liba/libarchive/libarchive-tools_3.4.0-2ubuntu1.2_amd64.deb",
        ),
        # https://packages.ubuntu.com/focal/amd64/libarchive13/download
        (
            "8ba7507f61bb3ea8da488702ec0badcbfb726d36ea6886e3421ac59082aaf2d1",
            "http://security.ubuntu.com/ubuntu/pool/main/liba/libarchive/libarchive13_3.4.0-2ubuntu1.2_amd64.deb",
        ),
        # https://packages.ubuntu.com/focal/amd64/libnettle7/download
        (
            "3496aed83407fde71e0dc5988b28e8fd7f07a2f27fcf3e0f214c7cd86667eecd",
            "http://security.ubuntu.com/ubuntu/pool/main/n/nettle/libnettle7_3.5.1+really3.5.1-2ubuntu0.2_amd64.deb",
        ),
        # https://packages.ubuntu.com/focal/amd64/libxml2/download
        (
            "cef3871873e5e7e7f1d01afec4d35f15504a9d8a0afbe56f57037e92f7f8e850",
            "http://security.ubuntu.com/ubuntu/pool/main/libx/libxml2/libxml2_2.9.10+dfsg-5ubuntu0.20.04.7_amd64.deb",
        ),
        # https://packages.ubuntu.com/focal/amd64/libicu66/download
        (
            "00d0de456134668f41bd9ea308a076bc0a6a805180445af8a37209d433f41efe",
            "http://security.ubuntu.com/ubuntu/pool/main/i/icu/libicu66_66.1-2ubuntu2.1_amd64.deb",
        ),
    ],
}

def _find_usable_system_tar(rctx, tar_name):
    """find_usable_system_tar searches the host for a tar executable that appears bsd-like

    Args:
        rctx: the repository context (type rctx)
        tar_name: the name of the tar binary to search for (type String)
    Returns:
        a struct having three String fields (name, path, error).  If the exe was found,
        path will the absolute path from ctx.which, and error will be None.
    """
    tar = rctx.which(tar_name)
    if not tar:
        return struct(
            name = tar_name,
            path = None,
            error = "not found on PATH, and we don't handle this case yet",
        )

    # Run tar --version and see if we are satisfied to use it
    tar_version = rctx.execute([tar, "--version"]).stdout.strip()

    # TODO: also check if it's really ancient or compiled without gzip support or something?
    # TODO: document how users could fetch the source and compile it themselves
    if tar_version.find("bsdtar") >= 0:
        return struct(
            path = tar,
            name = tar_name,
            error = None,
        )

    return struct(
        name = tar_name,
        path = tar,
        error = "isn't a BSD tar",
    )

def _bsdtar_binary_repo(rctx):
    build_header = """\
# @generated by @aspect_bazel_lib//lib/private:tar_toolchain.bzl

load("@aspect_bazel_lib//lib/private:tar_toolchain.bzl", "tar_toolchain")

package(default_visibility = ["//visibility:public"])

"""

    if rctx.attr.platform == "host":
        tars_checked = []
        for tar_name in rctx.attr.host_tar_names:
            tar = _find_usable_system_tar(rctx, tar_name)
            tars_checked.append(tar)
            if not tar.error:
                break
        tar = tars_checked[-1]  # last element in list is the first one found in the system (or not)
        if tar.error:
            fail("failed to find a host provided tar: %s" % tars_checked)
        output = rctx.path(tar.name)
        rctx.symlink(tar.path, output)
        rctx.file("BUILD.bazel", build_header + """tar_toolchain(name = "bsdtar_toolchain", binary = "%s")""" % tar.name)
        return

    if repo_utils.is_windows(rctx):
        rctx.download_and_extract(
            url = WINDOWS_DEPS[1],
            type = "zip",
            sha256 = WINDOWS_DEPS[0],
        )
        rctx.file("BUILD.bazel", build_header + """tar_toolchain(name = "bsdtar_toolchain", binary = "libarchive/bin/bsdtar.exe")""")
        return

    # Other platforms, we have more work to do.
    libs_dir = "usr/lib/x86_64-linux-gnu" if rctx.attr.platform.endswith("amd64") else "usr/lib/aarch64-linux-gnu"

    for lib in LINUX_LIB_DEPS[rctx.attr.platform]:
        rctx.download_and_extract(
            url = lib[1],
            type = "deb",
            sha256 = lib[0],
        )
        rctx.extract("data.tar.xz")

    rctx.file("bsdtar.sh", """#!/usr/bin/env bash
readonly wksp="$(dirname "${{BASH_SOURCE[0]}}")"
LD_LIBRARY_PATH=$wksp/{libs_dir} exec $wksp/usr/bin/bsdtar $@
""".format(name = rctx.name, libs_dir = libs_dir))

    rctx.file("BUILD.bazel", build_header + """\
tar_toolchain(
    name = "bsdtar_toolchain",
    files = glob(["{libs}/*.so.*"]) + ["usr/bin/bsdtar"],
    binary = "bsdtar.sh",
    visibility = ["//visibility:public"],
)
""".format(libs = libs_dir, name = rctx.name))

bsdtar_binary_repo = repository_rule(
    implementation = _bsdtar_binary_repo,
    attrs = {
        "platform": attr.string(mandatory = True, values = BSDTAR_PLATFORMS.keys()),
        "host_tar_names": attr.string_list(
            doc = "A list of possible names to use when searching for a host tar executable",
            default = ["tar.exe", "tar", "bsdtar.exe", "bsdtar"],
        ),
    },
)

TarInfo = provider(
    doc = "Provide info for executing BSD tar",
    fields = {
        "binary": "bsdtar executable",
    },
)

def _tar_toolchain_impl(ctx):
    binary = ctx.executable.binary

    # Make the $(BSDTAR_BIN) variable available in places like genrules.
    # See https://docs.bazel.build/versions/main/be/make-variables.html#custom_variables
    template_variables = platform_common.TemplateVariableInfo({
        "BSDTAR_BIN": binary.path,
    })

    default_info = DefaultInfo(
        files = depset(ctx.files.binary + ctx.files.files),
    )
    tarinfo = TarInfo(
        binary = binary,
    )

    # Export all the providers inside our ToolchainInfo
    # so the resolved_toolchain rule can grab and re-export them.
    toolchain_info = platform_common.ToolchainInfo(
        tarinfo = tarinfo,
        template_variables = template_variables,
        default = default_info,
    )

    return [toolchain_info, template_variables, default_info]

tar_toolchain = rule(
    implementation = _tar_toolchain_impl,
    attrs = {
        "binary": attr.label(
            doc = "a command to find on the system path",
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
        "files": attr.label_list(allow_files = True),
    },
)

def _tar_toolchains_repo_impl(rctx):
    # Expose a concrete toolchain which is the result of Bazel resolving the toolchain
    # for the execution or target platform.
    # Workaround for https://github.com/bazelbuild/bazel/issues/14009
    starlark_content = """\
# @generated by @aspect_bazel_lib//lib/private:tar_toolchain.bzl

# Forward all the providers
def _resolved_toolchain_impl(ctx):
    toolchain_info = ctx.toolchains["@aspect_bazel_lib//lib:tar_toolchain_type"]
    return [
        toolchain_info,
        toolchain_info.default,
        toolchain_info.tarinfo,
        toolchain_info.template_variables,
    ]

# Copied from java_toolchain_alias
# https://cs.opensource.google/bazel/bazel/+/master:tools/jdk/java_toolchain_alias.bzl
resolved_toolchain = rule(
    implementation = _resolved_toolchain_impl,
    toolchains = ["@aspect_bazel_lib//lib:tar_toolchain_type"],
    incompatible_use_toolchain_transition = True,
)
"""
    rctx.file("defs.bzl", starlark_content)

    build_content = """# @generated by @aspect_bazel_lib//lib/private:tar_toolchain.bzl
load(":defs.bzl", "resolved_toolchain")
load("@local_config_platform//:constraints.bzl", "HOST_CONSTRAINTS")

resolved_toolchain(name = "resolved_toolchain", visibility = ["//visibility:public"])"""

    for [platform, meta] in BSDTAR_PLATFORMS.items():
        build_content += """
toolchain(
    name = "{platform}_toolchain",
    exec_compatible_with = {compatible_with},
    toolchain = "@{user_repository_name}_{platform}//:bsdtar_toolchain",
    toolchain_type = "@aspect_bazel_lib//lib:tar_toolchain_type",
)
""".format(
            platform = platform,
            user_repository_name = rctx.attr.user_repository_name,
            compatible_with = meta.compatible_with,
        )

    rctx.file("BUILD.bazel", build_content)

tar_toolchains_repo = repository_rule(
    _tar_toolchains_repo_impl,
    doc = """Creates a repository that exposes a tar_toolchain_type target.""",
    attrs = {
        "user_repository_name": attr.string(doc = "Base name for toolchains repository"),
    },
)
