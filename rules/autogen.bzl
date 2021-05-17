"""TODO(cfrantz): Write module docstring."""

def _autogen_hjson_header(ctx):
  header = ctx.actions.declare_file("{}.h".format(ctx.label.name))
  ctx.actions.run(
      outputs = [header],
      inputs = ctx.files.srcs + ctx.files._tool,
      arguments = [
          "-D",
          "-o", header.path,
      ] + [src.path for src in ctx.files.srcs],
      executable = ctx.files._tool[0]
  )
  return [CcInfo(compilation_context=cc_common.create_compilation_context(
      includes=depset([header.dirname]),
      headers=depset([header]),
      ))]

autogen_hjson_header = rule(
    implementation = _autogen_hjson_header,
    attrs = {
        "srcs": attr.label_list(allow_files=True),
        "_tool": attr.label(default="//util:regtool.py", allow_files=True),
    },
)

def _chip_info(ctx):
  header = ctx.actions.declare_file("chip_info.h")
  ctx.actions.run(
      outputs = [header],
      inputs = ctx.files.version + ctx.files._tool,
      arguments = [
          "-o", header.dirname,
          "--ot_version_file", ctx.files.version[0].path,
      ],
      executable = ctx.files._tool[0]
  )
  return [CcInfo(compilation_context=cc_common.create_compilation_context(
      includes=depset([header.dirname]),
      headers=depset([header]),
      ))]

chip_info = rule(
    implementation = _chip_info,
    attrs = {
        "version": attr.label(default="//util:ot_version_file", allow_files=True),
        "_tool": attr.label(default="//util:rom_chip_info.py", allow_files=True),
    },
)
