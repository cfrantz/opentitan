# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Rules to describe OpenTitan HW"""

def opentitan_ip(name, hjson):
    """
    Return a structure describing an IP. This can be given to opentitan_top.

    Arguments:
    - name: name of ip in lower case.
    - hjson: label of the IP's hjson path, you MUST NOT use a relative label.
    - alias: label of an alias file.
    """
    return struct(
        name = name,
        hjson = hjson,
    )

def opentitan_top(name, hjson, top_lib, top_ld, ips):
    """
    Return a structure describing a top.

    Arguments:
    - name: name of top in lower case.
    - hjson: label of the top's hjson path (generated by topgen), you MUST NOT
             use a relative label.
    - top_lib: same but for the top's library.
    - top_ld: same but for the top's linker script.
    - ips: array of ips, the entries must be built by opentitan_ip().
    """
    return struct(
        name = name,
        hjson = hjson,
        top_lib = top_lib,
        top_ld = top_ld,
        ips = ips,
    )

OpenTitanTopInfo = provider(
    doc = "Information about an OpenTitan top",
    fields = {
        "name": "Name of this top (string)",
        "hjson": "topgen-generated HJSON file for this top (file)",
        "ip_hjson": "dictionary of IPs HSJON files (dict: string => file)",
    },
)

def _describe_top(ctx):
    ip_hjson = {}

    # We cannot use ctx.files because it is only a list and not a dict.
    for (ipname, hjson) in ctx.attr.ip_hjson.items():
        if len(hjson[DefaultInfo].files.to_list()) != 1:
            fail("IP {} in top {} must provide exactly one Hjson file".format(ipname, ctx.attr.topname))

        # Extract the file from the Target.
        ip_hjson[ipname] = hjson[DefaultInfo].files.to_list()[0]

    return [
        OpenTitanTopInfo(
            name = ctx.attr.topname,
            hjson = ctx.file.hjson,
            ip_hjson = ip_hjson,
        ),
    ]

describe_top_rule = rule(
    implementation = _describe_top,
    doc = """Create a target that provides the description of a top in the form of an OpenTitanTopInfo provider.""",
    attrs = {
        "hjson": attr.label(mandatory = True, allow_single_file = True, doc = "toplevel hjson file generated by topgen"),
        "ip_hjson": attr.string_keyed_label_dict(allow_files = True, doc = "mapping from hjson files to IP name"),
        "topname": attr.string(mandatory = True, doc = "Name of the top"),
    },
)

def describe_top(name, all_tops, top):
    """
    Create a target that provides an OpenTitanTopInfo corresponding to the
    requested top.

    - all_tops: list of tops (created by opentitan_top).
    - top: name of the top to use.
    """

    # Although we already pass the top description to the rule, those are just strings.
    # We also need to let bazel know that we depend on the hjson files which is why
    # we also pass them in a structured way.
    all_hjson = {}
    top_hjson = None
    for _top in all_tops:
        if _top.name != top:
            continue
        top_hjson = _top.hjson
        for ip in _top.ips:
            all_hjson[ip.name] = ip.hjson

    if top_hjson == None:
        fail("top {} not found in the provided list of tops".format(top))

    describe_top_rule(
        name = name,
        hjson = top_hjson,
        ip_hjson = all_hjson,
        topname = top,
    )

def select_top_lib(name, all_tops, top):
    """
    Create an alias to the top library.
    """
    libs = [_top.top_lib for _top in all_tops if _top.name == top]
    if len(libs) == 0:
        fail("not top found with name {}".format(top))

    native.alias(
        name = name,
        actual = libs[0],
    )

def select_top_ld(name, all_tops, top):
    """
    Create an alias to the top library.
    """
    libs = [_top.top_ld for _top in all_tops if _top.name == top]
    if len(libs) == 0:
        fail("not top found with name {}".format(top))

    native.alias(
        name = name,
        actual = libs[0],
    )