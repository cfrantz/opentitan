"""Bazel definitions for opentitan"""
load("//rules:bugfix.bzl", "find_cc_toolchain")

# TODO(cfrantz): update this after upstreaming the cpu definition to
# the bazel_platforms project.
OPENTITAN_CPU = "@bazel_embedded//constraints/cpu:rv32imc"
OPENTITAN_PLATFORM = "@bazel_embedded//platforms:rv32imc"

_targets_compatible_with = {
    OPENTITAN_PLATFORM: [OPENTITAN_CPU],
}

def _platforms_transition_impl(settings, attr):
  return {"//command_line_option:platforms": attr.platform}

_platforms_transition = transition(
    implementation = _platforms_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _elf_to_binary(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    outputs = []
    for src in ctx.files.srcs:
        binary = ctx.actions.declare_file("{}.bin".format(src.basename))
        outputs.append(binary)
        ctx.actions.run(
            outputs = [binary],
            inputs = [src] + cc_toolchain.all_files.to_list(),
            arguments = [
                "--output-target", "binary",
                src.path,
                binary.path,
            ],
            executable = cc_toolchain.objcopy_executable,
        )
    return [DefaultInfo(files=depset(outputs))]

elf_to_binary = rule(
    implementation = _elf_to_binary,
    cfg = _platforms_transition,
    attrs = {
        "srcs": attr.label_list(allow_files=True),
        "platform": attr.string(default=OPENTITAN_PLATFORM),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    },
    toolchains = ["@rules_cc//cc:toolchain_type"],
)

def _elf_to_disassembly(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    outputs = []
    for src in ctx.files.srcs:
        disassembly = ctx.actions.declare_file("{}.dis".format(src.basename))
        outputs.append(disassembly)
        ctx.actions.run_shell(
            outputs = [disassembly],
            inputs = [src] + cc_toolchain.all_files.to_list(),
            arguments = [
                cc_toolchain.objdump_executable,
                src.path,
                disassembly.path,
            ],
            command = "$1 --disassemble --headers --line-numbers --source $2 > $3",
        )
    return [DefaultInfo(files=depset(outputs))]

elf_to_disassembly = rule(
    implementation = _elf_to_disassembly,
    cfg = _platforms_transition,
    attrs = {
        "srcs": attr.label_list(allow_files=True),
        "platform": attr.string(default=OPENTITAN_PLATFORM),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    },
    toolchains = ["@rules_cc//cc:toolchain_type"],
    incompatible_use_toolchain_transition = True,
)

def _elf_to_scrambled(ctx):
    outputs = []
    for src in ctx.files.srcs:
        scrambled = ctx.actions.declare_file("{}.scr.40.vmem".format(src.basename))
        outputs.append(scrambled)
        ctx.actions.run(
            outputs = [scrambled],
            inputs = [
                src,
                ctx.files._tool[0],
                ctx.files._config[0],
            ],
            arguments = [
                ctx.files._config[0].path,
                src.path,
                scrambled.path,
            ],
            executable = ctx.files._tool[0].path,
        )
    return [DefaultInfo(files=depset(outputs))]

elf_to_scrambled = rule(
    implementation = _elf_to_scrambled,
    cfg = _platforms_transition,
    attrs = {
        "srcs": attr.label_list(allow_files=True),
        "platform": attr.string(default=OPENTITAN_PLATFORM),
        "_tool": attr.label(default="//hw:ip/rom_ctrl/util/scramble_image.py", allow_files=True),
        "_config": attr.label(default="//hw/top_earlgrey:data/autogen/top_earlgrey.gen.hjson", allow_files=True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    },
)

def opentitan_binary(
    name,
    platform = OPENTITAN_PLATFORM,
    per_device_deps = {
        "verilator": [ "//sw/device/lib/arch:sim_verilator" ],
        "dv": [ "//sw/device/lib/arch:sim_dv" ],
        "fpga_nexysvideo": [ "//sw/device/lib/arch:fpga_nexysvideo" ],
    },
    output_bin = True,
    output_disassembly = True,
    output_scrambled = False,
    **kwargs):

    deps = kwargs.pop("deps", [])
    targets = []
    for (device, dev_deps) in per_device_deps.items():
        devname = "{}_{}".format(name, device)
        native.cc_binary(
            name = devname,
            deps = deps + dev_deps,
            target_compatible_with = _targets_compatible_with[platform],
            **kwargs,
        )

        if output_bin:
            targets.append(":" + devname + "_bin")
            elf_to_binary(
                name = devname + "_bin",
                srcs = [devname],
                platform = platform,
            )
        if output_disassembly:
            targets.append(":" + devname + "_dis")
            elf_to_disassembly(
                name = devname + "_dis",
                srcs = [devname],
                platform = platform,
            )
        if output_scrambled:
            targets.append(":" + devname + "_scr")
            elf_to_scrambled(
                name = devname + "_scr",
                srcs = [devname],
                platform = platform,
            )

    native.filegroup(
        name = name,
        srcs = targets,
    )
