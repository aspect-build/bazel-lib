"""Our "development" dependencies

Users should *not* need to install these. If users see a load()
statement from these, that's a bug in our distribution.
"""

load("//lib:repositories.bzl", "register_bats_toolchains", "register_coreutils_toolchains", "register_jq_toolchains", "register_ripgrep_toolchains", "register_sd_toolchains", "register_tar_toolchains", "register_yq_toolchains")
load("//lib:utils.bzl", http_archive = "maybe_http_archive")

# buildifier: disable=unnamed-macro
def bazel_lib_internal_deps():
    "Fetch deps needed for local development"
    http_archive(
        name = "io_bazel_rules_go",
        sha256 = "6734a719993b1ba4ebe9806e853864395a8d3968ad27f9dd759c196b3eb3abe8",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.45.1/rules_go-v0.45.1.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.45.1/rules_go-v0.45.1.zip",
        ],
    )

    http_archive(
        name = "bazel_gazelle",
        sha256 = "32938bda16e6700063035479063d9d24c60eda8d79fd4739563f50d331cb3209",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.35.0/bazel-gazelle-v0.35.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.35.0/bazel-gazelle-v0.35.0.tar.gz",
        ],
    )

    http_archive(
        name = "bazel_skylib",
        sha256 = "cd55a062e763b9349921f0f5db8c3933288dc8ba4f76dd9416aac68acee3cb94",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.5.0/bazel-skylib-1.5.0.tar.gz",
        ],
    )

    http_archive(
        name = "bazel_skylib_gazelle_plugin",
        sha256 = "747addf3f508186234f6232674dd7786743efb8c68619aece5fb0cac97b8f415",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.5.0/bazel-skylib-gazelle-plugin-1.5.0.tar.gz",
        ],
    )

    http_archive(
        name = "io_bazel_stardoc",
        sha256 = "ec57139e466faae563f2fc39609da4948a479bb51b6d67aedd7d9b1b8059c433",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/stardoc/releases/download/0.5.4/stardoc-0.5.4.tar.gz",
            "https://github.com/bazelbuild/stardoc/releases/download/0.5.4/stardoc-0.5.4.tar.gz",
        ],
    )

    http_archive(
        name = "buildifier_prebuilt",
        sha256 = "72b5bb0853aac597cce6482ee6c62513318e7f2c0050bc7c319d75d03d8a3875",
        strip_prefix = "buildifier-prebuilt-6.3.3",
        urls = ["https://github.com/keith/buildifier-prebuilt/archive/6.3.3.tar.gz"],
    )

    http_archive(
        name = "aspect_rules_lint",
        sha256 = "604666ec7ffd4f5f2636001ae892a0fbc29c77401bb33dd10601504e3ba6e9a7",
        strip_prefix = "rules_lint-0.6.1",
        url = "https://github.com/aspect-build/rules_lint/releases/download/v0.6.1/rules_lint-v0.6.1.tar.gz",
    )

    http_archive(
        name = "bazel_features",
        sha256 = "f3082bfcdca73dc77dcd68faace806135a2e08c230b02b1d9fbdbd7db9d9c450",
        strip_prefix = "bazel_features-0.1.0",
        url = "https://github.com/bazel-contrib/bazel_features/releases/download/v0.1.0/bazel_features-v0.1.0.tar.gz",
    )

    # Register toolchains for tests
    register_jq_toolchains()
    register_ripgrep_toolchains()
    register_sd_toolchains()
    register_yq_toolchains()
    register_coreutils_toolchains()
    register_tar_toolchains()
    register_bats_toolchains(
        libraries = ["@aspect_bazel_lib//lib/tests/bats/bats-custom:custom"],
    )
