# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_tools//tools/build_defs/repo:local.bzl", "local_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@lowrisc_opentitan//rules:hub.bzl", "hub_repo")
load("@lowrisc_opentitan//rules:json.bzl", "json_load")

def _copy_from_label_impl(rctx):
    src_dir = rctx.path(rctx.attr.src)
    for p in src_dir.readdir():
        contents = rctx.read(p)
        rel_path = str(p)[len(str(src_dir)):].lstrip("/")
        rctx.file(rel_path, contents)

copy_from_label = repository_rule(
    implementation = _copy_from_label_impl,
    attrs = {
        "src": attr.label(),
    },
)

def _hooks_impl(rctx):
    for mod in rctx.modules:
        for repo in mod.tags.repo:
            d = rctx.getenv(repo.env)
            extras = None
            if d:
                local_repository(name = repo.name, path = d)
                extras = json_load(rctx, rctx.path(d).get_child(repo.extra))
            else:
                copy_from_label(name = repo.name, src = repo.dummy)
                extras = json_load(rctx, rctx.path(repo.dummy).get_child(repo.extra))

            repo_mapping = {}
            if extras:
                for extra in extras:
                    rule = extra.pop("rule", "http_archive")
                    name = extra.pop("name")
                    rootdir_file = extra.pop("rootdir_file", "BUILD.bazel")
                    newname = "{}_{}".format(repo.name, name)
                    if rule == "http_archive":
                        http_archive(name = newname, **extra)
                    elif rule == "local_repository":
                        local_repository(name = newname, **extra)
                    else:
                        fail("Unknown extra repository type:", rule)

                    repo_mapping[name] = "@{}//:{}".format(newname, rootdir_file)

            hub_repo(
                name = "{}_extra".format(repo.name),
                repo_mapping = repo_mapping,
            )

_repo_class = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "env": attr.string(mandatory = True),
        "dummy": attr.label(mandatory = True),
        "extra": attr.string(mandatory = False),
    },
)

hooks = module_extension(
    implementation = _hooks_impl,
    tag_classes = {"repo": _repo_class},
)
