# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

def strip_comments(content):
    """Strips //, /* */, and # comments from a JSON string.

    It is utterly intolerable to use JSON as a configuration file format
    without comments.  This function strips comments so bazel's built in
    JSON decoder can then process the JSON.

    Args:
        content: The JSON string to strip comments from.

    Returns:
        The comment-stripped JSON string.
    """
    res = []
    i = 0
    n = len(content)
    in_string = False
    in_multiline_comment = False
    in_singleline_comment = False

    for i in range(n):
        char = content[i]
        next_char = content[i + 1] if i + 1 < n else ""

        if in_multiline_comment:
            if char == "*" and next_char == "/":
                in_multiline_comment = False
                i += 1
        elif in_singleline_comment:
            if char == "\n":
                in_singleline_comment = False
                res.append(char)
        elif in_string:
            if char == "\\":
                res.append(char)
                if i + 1 < n:
                    res.append(content[i + 1])
                    i += 1
            elif char == "\"":
                in_string = False
                res.append(char)
            else:
                res.append(char)
        elif char == "/" and next_char == "*":
            in_multiline_comment = True
            i += 1
        elif char == "/" and next_char == "/":
            in_singleline_comment = True
            i += 1
        elif char == "#":
            in_singleline_comment = True
        elif char == "\"":
            in_string = True
            res.append(char)
        else:
            res.append(char)
        i += 1
    return "".join(res)

def json_decode(content):
    """Decodes a JSON string after stripping comments.

    Args:
        content: The JSON string with potential comments.

    Returns:
        The decoded JSON object.
    """
    return json.decode(strip_comments(content))

def json_load(rctx, path):
    """Reads a JSON file and decodes it after stripping comments.

    Args:
        rctx: The repository context.
        path: The path to the JSON file.

    Returns:
        The decoded JSON object, or None if the file does not exist or is a directory.
    """
    p = rctx.path(path)
    if p.exists and not p.is_dir:
        return json_decode(rctx.read(p))
    return None
