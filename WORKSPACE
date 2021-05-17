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
