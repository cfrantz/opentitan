load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

git_repository(
    name = "bazel_embedded",
    commit = "01a877112f925f86e957f347b248a456910b6ce7",
    remote = "https://github.com/cfrantz/bazel-embedded.git",
    shallow_since = "1621276501 -0700"
)

# For local development on the bazel-embedded project.
#local_repository(
#    name = "bazel_embedded",
#    path = "/usr/local/google/home/cfrantz/opentitan/bazel-embedded",
#)

load("@bazel_embedded//:bazel_embedded_deps.bzl", "bazel_embedded_deps")

bazel_embedded_deps()

load("@bazel_embedded//platforms:execution_platforms.bzl", "register_platforms")

register_platforms()

load(
    "@bazel_embedded//toolchains/compilers/lowrisc_toolchain_rv32imc:lowrisc_toolchain_rv32imc_repository.bzl",
    "lowrisc_toolchain_rv32imc_compiler",
)
lowrisc_toolchain_rv32imc_compiler()

load("@bazel_embedded//toolchains/lowrisc_toolchain_rv32imc:lowrisc_toolchain_rv32imc.bzl", "register_lowrisc_toolchain_rv32imc_toolchain")
register_lowrisc_toolchain_rv32imc_toolchain()

local_repository(
    name = "googletest",
    path = "sw/vendor/google_googletest",
)
# Abseil
http_archive(
     name = "com_google_absl",
     urls = ["https://github.com/abseil/abseil-cpp/archive/master.zip"],
     strip_prefix = "abseil-cpp-master",
)

http_archive(
    name = "rules_rust",
    sha256 = "accb5a89cbe63d55dcdae85938e56ff3aa56f21eb847ed826a28a83db8500ae6",
    strip_prefix = "rules_rust-9aa49569b2b0dacecc51c05cee52708b7255bd98",
    urls = [
        # Main branch as of 2021-02-19
        "https://github.com/bazelbuild/rules_rust/archive/9aa49569b2b0dacecc51c05cee52708b7255bd98.tar.gz",
    ],
)
load("@rules_rust//rust:repositories.bzl", "rust_repositories")
rust_repositories()

load("//third_party/cargo:crates.bzl", "raze_fetch_remote_crates")
raze_fetch_remote_crates()

