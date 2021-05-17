package(default_visibility = ["//visibility:public"])

cc_library(
    name = "top_earlgrey",
    hdrs = [
        "top_earlgrey.h",
        "top_earlgrey_memory.h",
    ],
    srcs = [
        "top_earlgrey.c",
    ],
)

#filegroup(
cc_library(
    name = "linker_script",
    deps = ["top_earlgrey_memory.ld"],
)
