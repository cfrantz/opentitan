package(default_visibility = ["//visibility:public"])

# TODO: refactor tools into proper targets.
exports_files(glob(['**']))

genrule(
    name = "ot_version_file",
    outs = ["ot_version.txt"],
    cmd = """awk '/BUILD_GIT_VERSION/ { print $$2 }' bazel-out/volatile-status.txt > $@""",
    stamp = 1,
)
