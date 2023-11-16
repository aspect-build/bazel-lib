"Module extensions for use with bzlmod"

load(
    "@aspect_bazel_lib//lib:repositories.bzl",
    "DEFAULT_COPY_DIRECTORY_REPOSITORY",
    "DEFAULT_COPY_TO_DIRECTORY_REPOSITORY",
    "DEFAULT_COREUTILS_REPOSITORY",
    "DEFAULT_COREUTILS_VERSION",
    "DEFAULT_EXPAND_TEMPLATE_REPOSITORY",
    "DEFAULT_JQ_REPOSITORY",
    "DEFAULT_JQ_VERSION",
    "DEFAULT_YQ_REPOSITORY",
    "DEFAULT_YQ_VERSION",
    "register_copy_directory_toolchains",
    "register_copy_to_directory_toolchains",
    "register_coreutils_toolchains",
    "register_expand_template_toolchains",
    "register_jq_toolchains",
    "register_yq_toolchains",
)
load("//lib/private:extension_utils.bzl", "extension_utils")
load("//lib/private:host_repo.bzl", "host_repo")

def _toolchain_extension(mctx):
    register_copy_directory_toolchains(register = False)
    register_copy_to_directory_toolchains(register = False)
    register_jq_toolchains(register = False)
    register_yq_toolchains(register = False)
    register_coreutils_toolchains(register = False)
    register_expand_template_toolchains(register = False)

    create_host_repo = False
    for module in mctx.modules:
        if len(module.tags.host) > 0:
            create_host_repo = True

    if create_host_repo:
        host_repo(name = "aspect_bazel_lib_host")

# TODO: some way for users to control repo name/version of the tools installed
ext = module_extension(
    implementation = _toolchain_extension,
    tag_classes = {"host": tag_class(attrs = {})},
)

# Backport the new host extension from bazel-lib 2.x so that downstream rulesets
# are compatible with 1.x and 2.x
def _host_extension_impl(mctx):
    create_host_repo = False
    for module in mctx.modules:
        if len(module.tags.host) > 0:
            create_host_repo = True

    if create_host_repo:
        host_repo(name = "aspect_bazel_lib_host")

host = module_extension(
    implementation = _host_extension_impl,
    tag_classes = {
        "host": tag_class(attrs = {}),
    },
)

# Backport the new toolchains extension from bazel-lib 2.x so that downstream rulesets
# are compatible with 1.x and 2.x
def _toolchains_extension_impl(mctx):
    extension_utils.toolchain_repos_bfs(
        mctx = mctx,
        get_tag_fn = lambda tags: tags.copy_directory,
        toolchain_name = "copy_directory",
        toolchain_repos_fn = lambda name, version: register_copy_directory_toolchains(name = name, register = False),
        get_version_fn = lambda attr: None,
    )

    extension_utils.toolchain_repos_bfs(
        mctx = mctx,
        get_tag_fn = lambda tags: tags.copy_to_directory,
        toolchain_name = "copy_to_directory",
        toolchain_repos_fn = lambda name, version: register_copy_to_directory_toolchains(name = name, register = False),
        get_version_fn = lambda attr: None,
    )

    extension_utils.toolchain_repos_bfs(
        mctx = mctx,
        get_tag_fn = lambda tags: tags.jq,
        toolchain_name = "jq",
        toolchain_repos_fn = lambda name, version: register_jq_toolchains(name = name, version = version, register = False),
    )

    extension_utils.toolchain_repos_bfs(
        mctx = mctx,
        get_tag_fn = lambda tags: tags.yq,
        toolchain_name = "yq",
        toolchain_repos_fn = lambda name, version: register_yq_toolchains(name = name, version = version, register = False),
    )

    extension_utils.toolchain_repos_bfs(
        mctx = mctx,
        get_tag_fn = lambda tags: tags.coreutils,
        toolchain_name = "coreutils",
        toolchain_repos_fn = lambda name, version: register_coreutils_toolchains(name = name, version = version, register = False),
    )

    extension_utils.toolchain_repos_bfs(
        mctx = mctx,
        get_tag_fn = lambda tags: tags.expand_template,
        toolchain_name = "expand_template",
        toolchain_repos_fn = lambda name, version: register_expand_template_toolchains(name = name, register = False),
        get_version_fn = lambda attr: None,
    )

toolchains = module_extension(
    implementation = _toolchains_extension_impl,
    tag_classes = {
        "copy_directory": tag_class(attrs = {"name": attr.string(default = DEFAULT_COPY_DIRECTORY_REPOSITORY)}),
        "copy_to_directory": tag_class(attrs = {"name": attr.string(default = DEFAULT_COPY_TO_DIRECTORY_REPOSITORY)}),
        "jq": tag_class(attrs = {"name": attr.string(default = DEFAULT_JQ_REPOSITORY), "version": attr.string(default = DEFAULT_JQ_VERSION)}),
        "yq": tag_class(attrs = {"name": attr.string(default = DEFAULT_YQ_REPOSITORY), "version": attr.string(default = DEFAULT_YQ_VERSION)}),
        "coreutils": tag_class(attrs = {"name": attr.string(default = DEFAULT_COREUTILS_REPOSITORY), "version": attr.string(default = DEFAULT_COREUTILS_VERSION)}),
        "expand_template": tag_class(attrs = {"name": attr.string(default = DEFAULT_EXPAND_TEMPLATE_REPOSITORY)}),
    },
)
