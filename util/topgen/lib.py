# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import logging as log
import re
import sys
from collections import OrderedDict, defaultdict
from copy import deepcopy
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

import hjson
from basegen.lib import Name
from basegen.typing import ConfigT
from mako.template import Template
from reggen.ip_block import IpBlock
from version_file import VersionInformation

# Ignore flake8 warning as the function is used in the template
# disable isort formatting, as conflicting with flake8
from .intermodule import find_otherside_modules  # noqa : F401 # isort:skip
from .intermodule import im_portname, im_defname, im_netname  # noqa : F401 # isort:skip
from .intermodule import get_direction  # noqa : F401 # isort:skip
from .intermodule import get_dangling_im_def  # noqa : F401 # isort:skip
from .typing import IpBlocksT


class CEnum(object):

    def __init__(self, top_name, name, repr_type=None):
        self.name = top_name + name
        self.repr_type = repr_type
        self.finalized = False

        self.constants = []
        self.meta_constants = []

    def add_constant(self, constant_name, docstring=""):
        assert not self.finalized

        full_name = self.name + constant_name

        value = len(self.constants)

        self.constants.append((full_name, value, docstring))

        return full_name

    def add_first_constant(self, docstring=""):
        assert len(self.constants) > 0, "cannot add a First constant to an empty enumeration"

        full_name = self.name + Name(["first"])

        _, first_val, _ = self.constants[0]

        self.meta_constants.append((full_name, first_val, r"\internal " + docstring))
        self.finalized = True

    def add_last_constant(self, docstring=""):
        assert len(self.constants) > 0, "cannot add a Last constant to an empty enumeration"
        full_name = self.name + Name(["last"])

        _, last_val, _ = self.constants[-1]

        self.meta_constants.append((full_name, last_val, r"\internal " + docstring))
        self.finalized = True

    def add_count_constant(self, docstring=""):
        full_name = self.name + Name(["count"])

        self.meta_constants.append((full_name, len(self.constants), r"\internal " + docstring))
        self.finalized = True

    def render(self) -> str:
        template = ("typedef enum ${enum.name.as_snake_case()} {\n"
                    "% for name, value, docstring in enum.constants + enum.meta_constants:\n"
                    "  ${name.as_c_enum()} = ${value}, /**< ${docstring} */\n"
                    "% endfor\n"
                    "} ${enum.name.as_c_type()};")
        return Template(template).render(enum=self)


class CArrayMapping(object):

    def __init__(self, top_name, name, output_type_name):
        self.name = top_name + name
        self.output_type_name = output_type_name

        self.mapping = OrderedDict()

    def add_entry(self, in_name, out_name):
        self.mapping[in_name] = out_name

    def render_declaration(self) -> str:
        template = (
            "extern const ${mapping.output_type_name.as_c_type()}\n"
            "    ${mapping.name.as_snake_case()}[${len(mapping.mapping)}];")
        return Template(template).render(mapping=self)

    def render_definition(self) -> str:
        template = (
            "const ${mapping.output_type_name.as_c_type()}\n"
            "    ${mapping.name.as_snake_case()}[${len(mapping.mapping)}] = {\n"
            "% for in_name, out_name in mapping.mapping.items():\n"
            "  [${in_name.as_c_enum()}] = ${out_name.as_c_enum()},\n"
            "% endfor\n"
            "};")
        return Template(template).render(mapping=self)


class RustEnum(object):

    def __init__(self,
                 top_name,
                 name,
                 repr_type=None,
                 derive_list=["Copy", "Clone", "PartialEq", "Eq"]):
        self.name = top_name + name
        self.short_name = name
        self.enum_counter = 0
        self.finalized = False
        self.first_value = None
        self.last_value = None
        self.last_value_docstring = None
        self.repr_type = repr_type
        self.derive_list = derive_list
        self.constants = []
        # todo add flag for doc strings

    def repr(self) -> str:
        if isinstance(self.repr_type, int):
            return "u" + str(self.repr_type)
        elif self.repr_type is None:
            return "u32"
        else:
            return self.repr_type

    def derive(self) -> str:
        if isinstance(self.derive_list, list):
            if len(self.derive_list) > 0:
                return "#[derive({})]\n".format(", ".join(self.derive_list))
        return ""

    def add_constant(self, constant_name: str, docstring="") -> str:
        assert not self.finalized
        full_name = constant_name
        value = self.enum_counter
        self.enum_counter += 1
        self.constants.append((full_name, value, docstring))
        return full_name

    def add_number_of_variants(self, docstring=""):
        assert not self.finalized
        _, last_val, _ = self.constants[-1]
        self.last_value = last_val + 1
        self.last_value_docstring = docstring
        self.finalized = True

    def calculate_range(self):
        _, last_val, _ = self.constants[-1]
        _, first_val, _ = self.constants[0]
        self.last_value = last_val
        self.first_value = first_val

    def render_host(self, gen_doc=False, gen_name=None) -> str:
        self.calculate_range()
        body = (
            "    pub enum ${enum.short_name.as_rust_type()}: ${enum.repr()} "
            "[default = Self::End] {\n"
            "% for name, value, docstring in enum.constants:\n"
            "        % if len(docstring) > 0  and gen_doc: \n"
            "        /// ${docstring}\n"
            "        % endif \n"
            "        ${name.as_rust_enum()} = ${value},\n"
            "% endfor\n"
            "        End = ${enum.last_value + 1},\n"
            "    }")
        return Template(body).render(enum=self)

    def render(self, gen_range=False, gen_cast=False, derive_list=None) -> str:
        if derive_list is not None:
            self.derive_list = derive_list
        self.calculate_range()
        body = ("${enum.derive()}"
                "#[repr(${enum.repr()})]\n"
                "pub enum ${enum.short_name.as_rust_type()} {\n"
                "% for name, value, docstring in enum.constants:\n"
                "    % if len(docstring) > 0 : \n"
                "    /// ${docstring}\n"
                "    % endif \n"
                "    ${name.as_rust_enum()} = ${value},\n"
                "% endfor\n"
                "}")

        impl = (
            "\n\n"
            "impl ${enum.short_name.as_rust_type()} {\n"
            "    % if enum.last_value_docstring:\n"
            "    /// ${enum.last_value_docstring}\n"
            "    % else: \n"
            "    /// Total number of enum variants \n"
            "    % endif \n"
            "    const NUMBER: usize = ${len(enum.constants)};\n"
            "    /// Enum first valid value\n"
            "    const FIRST: ${enum.repr()} = "
            "Self::${enum.constants[0][0].as_rust_enum()} as ${enum.repr()};\n"
            "    /// Enum last valid value\n"
            "    const LAST: ${enum.repr()} = "
            "Self::${enum.constants[-1][0].as_rust_enum()} as ${enum.repr()};\n"
            "}")

        cast = (
            "\n\n"
            "impl TryFrom<${enum.repr()}> for "
            "${enum.short_name.as_rust_type()} {\n"
            "    type Error = ${enum.repr()};\n"
            "    fn try_from(val: ${enum.repr()}) -> Result<Self, Self::Error> {\n"
            "        match val {\n"
            "            % for name, value, docstring in enum.constants:\n"
            "            ${value} => Ok(Self::${name.as_rust_enum()}),\n"
            "            % endfor \n"
            "            _ => Err(val),\n"
            "        }\n"
            "    }\n"
            "}")

        if gen_range:
            body += impl
        if gen_cast:
            body += cast
        return Template(body).render(enum=self)


class RustArrayMapping(object):

    def __init__(self, top_name, name, output_type_name):
        self.name = top_name + name
        self.short_name = name
        self.output_type_name = output_type_name

        self.mapping = OrderedDict()

    def add_entry(self, in_name, out_name):
        self.mapping[in_name] = out_name

    def render_definition(self) -> str:
        template = (
            "pub const ${mapping.short_name.as_rust_const()}: "
            "[${mapping.output_type_name.as_rust_type()}; ${len(mapping.mapping)}] = [\n"
            "% for in_name, out_name in mapping.mapping.items():\n"
            "    // ${in_name.as_rust_enum()} ->"
            " ${mapping.output_type_name.as_rust_type()}::${out_name.as_rust_enum()}\n"
            "    ${mapping.output_type_name.as_rust_type()}::${out_name.as_rust_enum()},\n"
            "% endfor\n"
            "];")
        return Template(template).render(mapping=self)


class RustFileHeader(object):

    def __init__(self, version_stamp: VersionInformation):
        self.data = version_stamp

    def render(self) -> str:
        template = ""
        if self.data.scm_version() is not None:
            template += "// Built for ${header.data.scm_version()}\n"
        if self.data.scm_revision() is not None:
            template += ("// https://github.com/lowRISC/opentitan/tree/"
                         "${header.data.scm_revision()}\n")
        if self.data.scm_status() is not None:
            template += "// Tree status: ${header.data.scm_status()}\n"
        if template != "":
            template = "\n" + template
        return Template(template).render(header=self)


class MemoryRegion(object):

    def __init__(self, top_name: Name, name: Name, addr_space: str,
                 base_addr: int, size_bytes: int):
        assert isinstance(base_addr, int)
        self.addr_space = addr_space
        addr_space_suffix = get_addr_space_suffix({'name': addr_space})
        if len(addr_space_suffix) > 0:
            # Trim the beginning underscore.
            addr_space_suffix = addr_space_suffix[1:]
            addr_space_name = Name.from_snake_case(addr_space_suffix)
            self.name = top_name + addr_space_name + name
        else:
            self.name = top_name + name
        self.short_name = name
        self.base_addr = base_addr
        self.size_bytes = size_bytes
        self.size_words = (size_bytes + 3) // 4

    def base_addr_name(self, short=False) -> str:
        if short:
            return self.short_name + Name(["base", "addr"])
        else:
            return self.name + Name(["base", "addr"])

    def offset_name(self, short=False) -> str:
        if short:
            return self.short_name + Name(["offset"])
        else:
            return self.name + Name(["offset"])

    def size_bytes_name(self, short=False) -> str:
        if short:
            return self.short_name + Name(["size", "bytes"])
        else:
            return self.name + Name(["size", "bytes"])

    def size_words_name(self, short=False) -> str:
        if short:
            return self.short_name + Name(["size", "words"])
        else:
            return self.name + Name(["size", "words"])


def load_cfg(cfg_path: str) -> Dict[str, object]:
    """Loads an hjson file and returns the dictionary.

    This is suitable for the config files used by topgen.
    """
    try:
        with open(cfg_path, "r") as fcfg:
            cfg = hjson.load(fcfg,
                             use_decimal=True,
                             object_pairs_hook=OrderedDict)
    except ValueError:
        raise SystemExit(f"Loading hjson at '{cfg_path}': {sys.exc_info()[1]}")
    except OSError:
        raise SystemExit(sys.exc_info()[1])
    return cfg


def is_ipcfg(ip: Path) -> bool:
    log.info("IP Path: %s" % repr(ip))
    ip_name = ip.parents[1].name
    hjson_name = ip.name

    log.info("IP Name(%s) and HJSON name (%s)" % (ip_name, hjson_name))

    if ip_name + ".hjson" == hjson_name or ip_name + "_reg.hjson" == hjson_name:
        return True
    return False


def search_ips(ip_path: Path) -> List[str]:
    """Return a list with the path to every Hjson file as a string"""
    p = ip_path.glob('*/data/*.hjson')

    # filter only ip_name/data/ip_name{_reg|''}.hjson
    ips = [x for x in p if is_ipcfg(x)]

    log.info("Filtered-in IP files: %s" % repr(ips))
    return ips


def get_ip_hjson_path(ip_name_snake: str, topcfg: ConfigT,
                      repotop: Path) -> Path:
    """Return the location of an IP's hjson file for a given top.

    This function should be called with the module['type'] for ipgen
    modules, since find_module is called with use_base_template_type
    set to False.
    """
    m = find_module(topcfg["module"],
                    ip_name_snake,
                    use_base_template_type=False)
    if is_ipgen(m):
        data_dir = repotop / "hw/top_{}/ip_autogen/{}/data".format(
            topcfg["name"], ip_name_snake)
    elif is_top_reggen(m):
        data_dir = repotop / "hw/top_{}/ip/{}/data/".format(
            topcfg["name"], ip_name_snake)
    else:
        data_dir = repotop / "hw/ip/{}/data".format(ip_name_snake)
    return data_dir / "{}.hjson".format(ip_name_snake)


def is_xbarcfg(xbar_obj: ConfigT) -> bool:
    if "type" in xbar_obj and xbar_obj["type"] == "xbar":
        return True

    return False


def get_hjsonobj_xbars(xbar_path: Path) -> Dict[str, ConfigT]:
    """ Search crossbars Hjson files from given path.

    Search every Hjson in the directory and check Hjson type.
    It could be type: "top" or type: "xbar"
    returns [(name, obj), ... ]
    """
    paths = xbar_path.glob('*.hjson')
    xbar_objs = [load_cfg(p) for p in paths]
    xbar_objs = {x['name']: x for x in xbar_objs if is_xbarcfg(x)}

    return xbar_objs


def get_module_by_name(top: ConfigT, name: str) -> Optional[ConfigT]:
    """Search in top["module"] by name
    """
    module = None
    for m in top["module"]:
        if m["name"] == name:
            module = m
            break

    return module


def intersignal_to_signalname(top, m_name: str, s_name: str) -> str:

    # TODO: Find the signal in the `inter_module_list` and get the correct
    # signal name

    return "{m_name}_{s_name}".format(m_name=m_name, s_name=s_name)


def get_package_name_by_intermodule_signal(top: ConfigT, struct: str) -> str:
    """Search inter-module signal package with the struct name

    For instance, if `flash_ctrl` has inter-module signal package,
    this function returns the package name
    """
    instances = top["module"] + top["memory"]

    intermodule_instances = [
        x["inter_signal_list"] for x in instances if "inter_signal_list" in x
    ]

    for m in intermodule_instances:
        if m["name"] == struct and "package" in m:
            return m["package"]
    return ""


def get_signal_by_name(module: ConfigT, name: str):
    """Return the signal struct with the type input/output/inout
    """
    result = None
    for s in module["available_input_list"] + module[
            "available_output_list"] + module["available_inout_list"]:
        if s["name"] == name:
            result = s
            break

    return result


def add_module_prefix_to_signal(signal, module: str) -> str:
    """Add module prefix to module signal format { name: "sig_name", width: NN }
    """
    result = deepcopy(signal)

    if "name" not in signal:
        raise SystemExit("signal {} doesn't have name field".format(signal))

    result["name"] = module + "_" + signal["name"]
    result["module_name"] = module

    return result


def get_ms_name(name: str) -> Tuple[str, Optional[str]]:
    """Split module_name.signal_name to module_name , signal_name
    """

    tokens = name.split('.')

    if len(tokens) == 0:
        raise SystemExit("This to be catched in validate.py")

    module = tokens[0]
    signal = None
    if len(tokens) == 2:
        signal = tokens[1]

    return module, signal


def parse_pad_field(padstr: str) -> Tuple[str, str, str]:
    """Parse PadName[NN...NN] or PadName[NN] or just PadName
    """
    match = re.match(r'^([A-Za-z0-9_]+)(\[([0-9]+)(\.\.([0-9]+))?\]|)', padstr)
    return match.group(1), match.group(3), match.group(5)


def get_pad_list(padstr: str) -> List[Dict[str, Union[str, int]]]:
    pads = []

    pad, first, last = parse_pad_field(padstr)
    if first is None:
        first = 0
        last = 0
    elif last is None:
        last = first
    first = int(first, 0)
    last = int(last, 0)
    # width = first - last + 1

    for p in range(first, last + 1):
        pads.append(OrderedDict([("name", pad), ("index", p)]))

    return pads


def idx_of_last_module_with_params(top: ConfigT) -> int:
    last = -1
    for idx, module in enumerate(top["module"]):
        if len(module["param_list"]):
            last = idx
    return last


# Template functions
def ljust(x, width):
    return "{:<{width}}".format(x, width=width)


def bitarray(d: int, width: int) -> str:
    """Print Systemverilog bit array

    @param d the bit width of the signal
    @param width max character width of the signal group

    For instance, if width is 4, the max d value in the signal group could be
    9999. If d is 2, then this function pads 3 spaces at the end of the bit
    slice.

    "[1:0]   " <- d:=2, width=4
    "[9999:0]" <- max d-1 value

    If d is 1, it means array slice isn't necessary. So it returns empty spaces
    """

    if d <= 0:
        log.error("lib.bitarray: Given value {} is smaller than 1".format(d))
        raise ValueError
    if d == 1:
        return " " * (width + 4)  # [x:0] needs 4 more space than char_width

    out = "[{}:0]".format(d - 1)
    return out + (" " * (width - len(str(d))))


def parameterize(text: str) -> str:
    """Return the value wrapping with quote if not integer nor bits
    """
    if re.match(r'(\d+\'[hdb]\s*[0-9a-f_A-F]+|[0-9]+)', text) is None:
        return "\"{}\"".format(text)

    return text


def index(i: int) -> str:
    """Return index if it is not -1
    """
    return "[{}]".format(i) if i != -1 else ""


def get_clk_name(clk: str) -> str:
    """Return the appropriate clk name
    """
    if clk == 'main':
        return 'clk_i'
    else:
        return "clk_{}_i".format(clk)


def is_shadowed_port(block: IpBlock, port: str) -> bool:
    """Return boolean indication whether a port is a shadow reset port
    """
    shadowed_port = block.clocking.primary.reset if block.has_shadowed_reg() \
        else None

    return port == shadowed_port


def shadow_name(name: str) -> str:
    """Return the appropriate shadow reset name based on port name
    """
    match = re.match(r'^rst_([A-Za-z0-9_]+)_ni?', name)
    if match:
        return f'rst_{match.group(1)}_shadowed_ni'
    else:
        return 'rst_shadowed_ni'


def get_clock_lpg_path(top: object,
                       clk_name: str,
                       unmanaged_clock: bool = False) -> str:
    """Return the appropriate LPG clock path given name
    """
    if unmanaged_clock:
        return top['unmanaged_clocks'].get_clock_by_signal_name(
            clk_name).cg_en_signal
    else:
        clk_name = clk_name.split('clk_')[-1]
        return top['clocks'].hier_paths['lpg'] + clk_name


def get_reset_path(top: object,
                   reset: Union[str, object],
                   shadow_sel: bool = False,
                   unmanaged_reset: bool = False) -> str:
    """Return the appropriate reset path given name
    """
    if unmanaged_reset:
        return top['unmanaged_resets'].get(reset['name']).signal_name
    else:
        return top['resets'].get_path(reset['name'], reset['domain'],
                                      shadow_sel)


def get_reset_lpg_path(top: object,
                       reset: Union[str, object],
                       shadow_sel: bool = False,
                       domain: bool = None,
                       unmanaged_reset: bool = False) -> str:
    """Return the appropriate LPG reset path given name
    """
    if unmanaged_reset:
        return top['unmanaged_resets'].get(reset['name']).rst_en_signal_name
    else:
        if domain is not None:
            return top['resets'].get_lpg_path(reset['name'], domain,
                                              shadow_sel)
        else:
            return top['resets'].get_lpg_path(reset['name'], reset['domain'],
                                              shadow_sel)


def get_unused_resets(top: ConfigT) -> Dict:
    """Return dict of unused resets and associated domain
    """
    return top['resets'].get_unused_resets(top['power']['domains'])


def get_ipgen_modules(top: ConfigT) -> List[ConfigT]:
    """Returns list of all ipgen modules.
    """
    return [m['type'] for m in top['module'] if is_ipgen(m)]


def get_top_reggen_modules(top: ConfigT) -> List[ConfigT]:
    """Returns list of all ipgen modules.
    """
    return [m['type'] for m in top['module'] if is_top_reggen(m)]


def is_module_attr_valid(module: ConfigT) -> bool:
    return ('attr' not in module or
            module.get('attr') in ["ipgen", "reggen_top", "reggen_only"])


def is_ipgen(module: ConfigT) -> bool:
    """Returns an indication where a particular module is ipgen
    """
    return module.get('attr') in ["ipgen"]


def is_top_reggen(module: ConfigT) -> bool:
    """Returns an indication where a particular module is NOT generated
       and requires top level specific reggen
    """
    return module.get('attr') in ["reggen_top", "reggen_only"]


def is_reggen_only(module: ConfigT) -> bool:
    """Returns an indication where a particular module is NOT generated,
       requires top level specific reggen and is NOT instantiated in the
       top
    """
    return module.get('attr') == "reggen_only"


def is_inst(module: ConfigT) -> bool:
    """Returns an indication where a particular module should be instantiated
       in the top level
    """
    top_level_module = False
    top_level_mem = False

    if "attr" not in module:
        top_level_module = True
    elif module["attr"] in ["normal", "ipgen", "reggen_top"]:
        top_level_module = True
    elif module["attr"] in ["reggen_only"]:
        top_level_module = False
    else:
        raise ValueError('Attribute {} in {} is not valid'.format(
            module['attr'], module['name']))

    if module['type'] in ['rom', 'ram_1p_scr', 'eflash']:
        top_level_mem = True

    return top_level_mem or top_level_module


def get_base_and_size(name_to_block: IpBlocksT, inst: ConfigT,
                      ifname: Optional[str]) -> Tuple[int, int]:

    block = name_to_block.get(inst['type'])
    if block is None:
        # If inst isn't the instantiation of a block, it came from some memory.
        # Memories have their sizes defined, so we can just look it up there.
        bytes_used = int(inst['size'], 0)

        # Memories don't have multiple or named interfaces, so this will only
        # work if ifname is None.
        assert ifname is None
        base_addrs = deepcopy(inst['base_addr'])

    else:
        # If inst is the instantiation of some block, find the register block
        # that corresponds to ifname
        rb = block.reg_blocks.get(ifname)
        if rb is None:
            raise RuntimeError(
                'Cannot connect to non-existent {} device interface '
                'on {!r} (an instance of the {!r} block).'.format(
                    'default' if ifname is None else repr(ifname),
                    inst['name'], block.name))
        else:
            bytes_used = 1 << rb.get_addr_width()

        base_addrs = deepcopy(inst['base_addrs'][ifname])

        # If an instance has a nonempty "memory" field, take the memory
        # size configuration from there.
        if "memory" in inst:
            if ifname in inst["memory"]:
                memory_size = int(inst["memory"][ifname]["size"], 0)
                if bytes_used > memory_size:
                    raise RuntimeError(
                        'Memory region on {} device interface '
                        'on {!r} (an instance of the {!r} block) '
                        'is smaller than the corresponding register block.'.
                        format('default' if ifname is None else repr(ifname),
                               inst['name'], block.name))

                bytes_used = memory_size

    # Round up to next power of 2.
    size_byte = 1 << (bytes_used - 1).bit_length()

    for (asid, base_addr) in base_addrs.items():
        if isinstance(base_addr, str):
            base_addrs[asid] = int(base_addr, 0)
        else:
            assert isinstance(base_addrs[asid], int)

    return (base_addrs, size_byte)


def get_io_enum_literal(sig: Dict, prefix: str) -> str:
    """Returns the DIO pin enum literal with value assignment"""
    name = Name.from_snake_case(prefix) + Name.from_snake_case(sig["name"])
    # In this case, the signal is a multibit signal, and hence
    # we have to make the signal index part of the parameter
    # name to uniquify it.
    if sig['width'] > 1:
        name += Name([str(sig['idx'])])
    return name.as_camel_case()


def make_bit_concatenation(sig_name: str, indices: List[int],
                           end_indent: int) -> str:
    '''Return SV code for concatenating certain indices from a signal

    sig_name is the name of the signal and indices is a non-empty list of the
    indices to use, MSB first. So

      make_bit_concatenation("foo", [0, 100, 20])

    should give

      {foo[0], foo[100], foo[20]}

    Adjacent bits turn into a range select. For example:

      make_bit_concatenation("foo", [0, 1, 2])

    should give

      foo[0:2]

    If there are multiple ranges, they are printed one to a line. end_indent
    gives the indentation of the closing brace and the range selects in between
    get indented to end_indent + 2.

    '''
    assert 0 <= end_indent

    ranges = []
    cur_range_start = indices[0]
    cur_range_end = indices[0]
    for idx in indices[1:]:
        if idx == cur_range_end + 1 and cur_range_start <= cur_range_end:
            cur_range_end += 1
            continue
        if idx == cur_range_end - 1 and cur_range_start >= cur_range_end:
            cur_range_end -= 1
            continue
        ranges.append((cur_range_start, cur_range_end))
        cur_range_start = idx
        cur_range_end = idx
    ranges.append((cur_range_start, cur_range_end))

    items = []
    for range_start, range_end in ranges:
        if range_start == range_end:
            select = str(range_start)
        else:
            select = '{}:{}'.format(range_start, range_end)
        items.append('{}[{}]'.format(sig_name, select))

    if len(items) == 1:
        return items[0]

    item_indent = '\n' + (' ' * (end_indent + 2))

    acc = ['{', item_indent, items[0]]
    for item in items[1:]:
        acc += [',', item_indent, item]
    acc += ['\n', ' ' * end_indent, '}']
    return ''.join(acc)


def num_rom_ctrl(modules: List[ConfigT]) -> int:
    '''Return number of rom_ctrl's instantiated in the design
    '''
    num = 0
    for m in modules:
        if m['type'] == 'rom_ctrl':
            num += 1

    return num


def find_modules(modules: List[Dict[str, object]],
                 type: str,
                 use_base_template_type=True) -> List[Dict[str, object]]:
    '''Returns the modules of a given type

    If use_base_template_type is set to True, ipgen-based modules are
    searched using the "template_type" attribute. If set to False,
    the search uses the "type" attribute instead.
    '''
    modules_found = []
    for m in modules:
        if m.get('attr') == 'ipgen' and use_base_template_type:
            if m['template_type'] == type:
                modules_found.append(m)
        else:
            if m['type'] == type:
                modules_found.append(m)

    return modules_found


def find_module(
        modules: List[Dict[str, object]],
        type: str,
        use_base_template_type=True) -> Optional[List[Dict[str, object]]]:
    '''Returns the first module of a given type

    If use_base_template_type is set to True, ipgen-based modules are
    searched using the "template_type" attribute. If set to False,
    the search uses the "type" attribute instead.
    '''
    mods = find_modules(modules, type, use_base_template_type)
    return mods[0] if mods else None


def get_addr_space(top: ConfigT, addr_space_name: str) -> ConfigT:
    """Returns the address dict for a given address space name"""
    for addr_space in top['addr_spaces']:
        if addr_space['name'] == addr_space_name:
            return addr_space
    assert False, "Address space not found"


def get_device_ranges(devices, device_name):
    ranges = {}
    for (dev_name, if_name), range in devices:
        if dev_name == device_name:
            ranges[if_name] = range
    return ranges


def get_addr_space_suffix(addr_space: str) -> str:
    # TODO: Don't special-case the "hart" address space.
    if addr_space['name'] == "hart":
        return ""
    return "_" + addr_space['name']


def remove_prefix(s: str, prefix: str) -> str:
    return s[len(prefix):] if s.startswith(prefix) else s


class TopGen:

    def __init__(self, top_info: ConfigT, name_to_block: IpBlocksT, enum_type,
                 array_mapping_type):
        self.top = top_info
        self._top_name = Name(["top"]) + Name.from_snake_case(top_info["name"])
        self._name_to_block = name_to_block
        self.regwidth = int(top_info["datawidth"])

        assert enum_type in [CEnum, RustEnum], "Unsupported enum type"
        assert array_mapping_type in [CArrayMapping, RustArrayMapping], \
               "Unsupported array mapping type"
        self._enum_type = enum_type
        self._array_mapping_type = array_mapping_type

        if "interrupts" in self.top:
            self.default_plic = self.top["interrupts"].get("default_plic")
        else:
            self.default_plic = None
        self._init_plics()

        # Only generate alert_handler and mappings if there is an alert_handler
        if find_module(self.top['module'], 'alert_handler'):
            self._init_alert_mapping()
        # Only generate pinmux and pad mappings if there is a pinmux
        if find_module(self.top['module'], 'pinmux'):
            self._init_pinmux_mapping()
            self._init_pad_mapping()
        # Only generate pwrmgr mappings if there is a pwrmgr
        if find_module(self.top['module'], 'pwrmgr'):
            self._init_pwrmgr_wakeups()
            self._init_pwrmgr_reset_requests()
        # Only generate rstmgr mappings if there is a rstmgr
        if find_module(self.top['module'], 'rstmgr'):
            self._init_rstmgr_sw_rsts()
        # Only generate clkmgr mappings if there is a clkmgr
        if find_module(self.top['module'], 'clkmgr'):
            self._init_clkmgr_clocks()

        self.device_regions = defaultdict(dict)
        self.subranges = defaultdict(dict)
        for addr_space in top_info['addr_spaces']:
            self._init_device_regions(addr_space['name'])
            self._init_subranges(addr_space['name'])

    def _init_device_regions(self, addr_space):
        '''Initialize the device_regions dictionary.

        The dictionary entry maps blocks to MemoryRegions for the given
        addr_space.
        '''
        device_region = defaultdict(dict)
        for inst in self.top['module']:
            block = self._name_to_block[inst['type']]
            for if_name, rb in block.reg_blocks.items():
                full_if = (inst['name'], if_name)
                full_if_name = Name.from_snake_case(full_if[0])
                if if_name is not None:
                    full_if_name += Name.from_snake_case(if_name)

                name = full_if_name
                base, size = get_base_and_size(self._name_to_block, inst,
                                               if_name)
                if addr_space not in base:
                    continue

                region = MemoryRegion(self._top_name, name, addr_space,
                                      base[addr_space], size)
                device_region[inst['name']].update({if_name: region})

        self.device_regions[addr_space] = device_region

    def all_device_regions(self) -> Dict[str, Dict[str, MemoryRegion]]:
        '''Return a list of MemoryRegion objects for all devices on the bus.
        '''
        return self.device_regions

    def devices(
            self, addr_space
    ) -> List[Tuple[Tuple[str, Optional[str]], MemoryRegion]]:
        '''Return a list of MemoryRegion objects for devices on the bus

        The list returned is pairs (full_if, region) where full_if is itself a
        pair (inst_name, if_name). inst_name is the name of some IP block
        instantiation. if_name is the name of the interface (may be None).
        region is a MemoryRegion object representing the device.

        Parameters:
            addr_space: The address space representing the bus for generation.
        '''
        ret = []  # type: List[Tuple[Tuple[str, Optional[str]], MemoryRegion]]
        # TODO: This method is invoked in templates, as well as in the extended
        # class TopGenCTest. We could refactor and optimize the implementation
        # a bit.
        for inst in self.top['module']:
            block = self._name_to_block[inst['type']]
            for if_name, rb in block.reg_blocks.items():
                full_if = (inst['name'], if_name)
                full_if_name = Name.from_snake_case(full_if[0])
                if if_name is not None:
                    full_if_name += Name.from_snake_case(if_name)

                name = full_if_name
                base, size = get_base_and_size(self._name_to_block, inst,
                                               if_name)
                if addr_space not in base:
                    continue

                region = MemoryRegion(self._top_name, name, addr_space,
                                      base[addr_space], size)
                ret.append((full_if, region))

        return ret

    def memories(self, addr_space) -> List[Tuple[str, MemoryRegion]]:
        '''Return a list of MemoryRegions objects for memories on the bus

        Parameters:
            addr_space: The address space representing the bus for generation.
        '''
        ret = []
        for m in self.top["memory"]:
            ret.append((m["name"],
                        MemoryRegion(self._top_name,
                                     Name.from_snake_case(m["name"]),
                                     addr_space,
                                     int(m["base_addr"][addr_space], 0),
                                     int(m["size"], 0))))

        for inst in self.top['module']:
            if "memory" in inst:
                for if_name, val in inst["memory"].items():
                    base, size = get_base_and_size(self._name_to_block, inst,
                                                   if_name)
                    if addr_space not in base:
                        continue

                    name = Name.from_snake_case(val["label"])
                    region = MemoryRegion(self._top_name, name, addr_space,
                                          base[addr_space], size)
                    ret.append((val["label"], region))

        return ret

    def _init_plics(self):
        self.plic_targets = {}
        self.plic_sources = {}
        self.plic_interrupts = {}
        self.plic_mapping = {}
        self.device_irqs = {}

        for plic in find_modules(self.top["module"], "rv_plic"):
            plic_targets = self._init_plic_targets(plic)
            name = plic["name"]
            self.plic_targets[name] = plic_targets

            plic_sources, plic_interrupts, plic_mapping = self._init_plic_mapping(plic)
            self.plic_sources[name] = plic_sources
            self.plic_interrupts[name] = plic_interrupts
            self.plic_mapping[name] = plic_mapping

    def _init_plic_targets(self, plic):
        unsnaked_name = Name.from_snake_case(remove_prefix(plic["name"], "rv_"))
        enum = self._enum_type(self._top_name, unsnaked_name + Name(["target"]))

        # In the special case of one target called "rv_core_ibex",
        # call this "Ibex0" for compatibility with existing tests.
        targets = plic.get("targets", [])
        if len(targets) == 1 and targets[0] == "rv_core_ibex":
            enum.add_constant(Name(["ibex", "0"]), docstring="Ibex Core 0")
        else:
            for target in targets:
                shortened_target = remove_prefix(target, "rv_core_")
                enum.add_constant(Name.from_snake_case(shortened_target),
                                  docstring="Ibex {}".format(target))

        if isinstance(enum, RustEnum):
            enum.add_number_of_variants("Final number of PLIC target")
        else:
            enum.add_last_constant("Final PLIC target")

        return enum

    def _init_plic_mapping(self, plic):
        """We eventually want to generate a mapping from interrupt id to the
        source peripheral.

        In order to do so, we generate two enums (one for interrupts, one for
        sources), and store the generated names in a dictionary that represents
        the mapping.

        PLIC Interrupt ID 0 corresponds to no interrupt, and so no peripheral,
        so we encode that in the enum as "unknown".

        The interrupts have to be added in order, with "none" first, to ensure
        that they get the correct mapping to their PLIC id, which is used for
        addressing the right registers and bits.
        """
        # A lot of code counts on this being named "Plic" and not "RvPlic"
        unsnaked_name = Name.from_snake_case(remove_prefix(plic["name"], "rv_"))
        sources = self._enum_type(self._top_name, unsnaked_name + Name(["peripheral"]),
                                  self.regwidth)
        interrupts = self._enum_type(self._top_name,
                                     unsnaked_name + Name(["irq", "id"]), self.regwidth)
        plic_mapping = self._array_mapping_type(
            self._top_name, unsnaked_name + Name(["interrupt", "for", "peripheral"]),
            sources.short_name
            if isinstance(sources, RustEnum) else sources.name)

        unknown_source = sources.add_constant(Name(["unknown"]),
                                              docstring="Unknown Peripheral")
        none_irq_id = interrupts.add_constant(Name(["none"]),
                                              docstring="No Interrupt")
        plic_mapping.add_entry(none_irq_id, unknown_source)

        # When we generate the `interrupts` enum, the only info we have about
        # the source is the module name. We'll use `source_name_map` to map a
        # short module name to the full name object used for the enum constant.
        source_name_map = {'unknown': unknown_source}

        my_modules = {x["name"] for x in self.top["module"]
                      if x.get("plic", self.default_plic) == plic["name"]}
        for name in self.top["interrupt_module"]:
            if name not in my_modules:
                continue

            source_name = sources.add_constant(Name.from_snake_case(name),
                                               docstring=name)
            source_name_map[name] = source_name

        if isinstance(sources, RustEnum):
            sources.add_number_of_variants("Number of PLIC peripheral")
        else:
            sources.add_last_constant("Final PLIC peripheral")

        # Maintain a list of instance-specific IRQs organized first by PLIC, then by instance name.
        self.device_irqs[plic["name"]] = defaultdict(list)
        for intr in self.top["interrupt"]:
            if intr.get("plic", self.default_plic) != plic["name"]:
                continue

            # Some interrupts are multiple bits wide. Here we deal with that by
            # adding a bit-index suffix
            if "width" in intr and int(intr["width"]) != 1:
                for i in range(int(intr["width"])):
                    name = Name.from_snake_case(intr["name"]) + Name([str(i)])
                    irq_id = interrupts.add_constant(name,
                                                     docstring="{} {}".format(
                                                         intr["name"], i))
                    source_name_key = 'unknown' if intr['incoming'] else intr[
                        'module_name']
                    source_name = source_name_map[source_name_key]
                    plic_mapping.add_entry(irq_id, source_name)
                    self.device_irqs[plic["name"]][intr["module_name"]].append(intr["name"] +
                                                                               str(i))
            else:
                name = Name.from_snake_case(intr["name"])
                irq_id = interrupts.add_constant(name, docstring=intr["name"])
                source_name_key = 'unknown' if intr['incoming'] else intr[
                    'module_name']
                source_name = source_name_map[source_name_key]
                plic_mapping.add_entry(irq_id, source_name)
                self.device_irqs[plic["name"]][intr["module_name"]].append(intr["name"])

        if isinstance(interrupts, RustEnum):
            interrupts.add_number_of_variants("Number of Interrupt ID.")
        else:
            interrupts.add_last_constant("The Last Valid Interrupt ID.")

        return (sources, interrupts, plic_mapping)

    def _init_alert_mapping(self):
        """We eventually want to generate a mapping from alert id to the source
        peripheral.

        In order to do so, we generate two enums (one for alerts, one for
        sources), and store the generated names in a dictionary that represents
        the mapping.

        Alert Handler has no concept of "no alert", unlike the PLIC.

        The alerts have to be added in order, to ensure that they get the
        correct mapping to their alert id, which is used for addressing the
        right registers and bits.
        """
        # TODO: Model alert domains with explicit connectivity.
        sources = self._enum_type(self._top_name,
                                  Name(["alert", "peripheral"]), self.regwidth)
        alerts = self._enum_type(self._top_name, Name(["alert", "id"]),
                                 self.regwidth)
        alert_mapping = self._array_mapping_type(
            self._top_name, Name(["alert", "for", "peripheral"]),
            sources.short_name
            if isinstance(sources, RustEnum) else sources.name)

        external_source = sources.add_constant(Name(["external"]),
                                               docstring="External Peripheral")

        # When we generate the `alerts` enum, the only info we have about the
        # source is the module name. We'll use `source_name_map` to map a short
        # module name to the full name object used for the enum constant.
        source_name_map = {'external': external_source}

        for name in self.top["alert_module"]:
            source_name = sources.add_constant(Name.from_snake_case(name),
                                               docstring=name)
            source_name_map[name] = source_name

        if isinstance(sources, RustEnum):
            sources.add_number_of_variants("Final number of Alert peripheral")
        else:
            sources.add_last_constant("Final Alert peripheral")

        def add_alert(alert, name_prefix=None):
            alert_module = alert['module_name']

            if 'width' in alert and int(alert['width']) != 1:
                for i in range(int(alert['width'])):
                    name = Name.from_snake_case(alert['name']) + Name([str(i)])
                    if name_prefix:
                        name = Name.from_snake_case(name_prefix) + name
                        alert_module = f'{name_prefix}_{alert_module}'

                    alert_id = alerts.add_constant(
                        name, docstring=name.as_snake_case())
                    source_name_key = ('external'
                                       if name_prefix else alert_module)
                    source_name = source_name_map[source_name_key]
                    alert_mapping.add_entry(alert_id, source_name)
                    self.device_alerts[alert_module].append(
                        name.as_snake_case() + str(i))
            else:
                name = Name.from_snake_case(alert['name'])
                if name_prefix:
                    name = Name.from_snake_case(name_prefix) + name
                    alert_module = f'{name_prefix}_{alert_module}'

                alert_id = alerts.add_constant(name,
                                               docstring=name.as_snake_case())
                source_name_key = 'external' if name_prefix else alert_module
                source_name = source_name_map[source_name_key]
                alert_mapping.add_entry(alert_id, source_name)
                self.device_alerts[alert_module].append(name.as_snake_case())

        self.device_alerts = defaultdict(list)
        for alert in self.top["alert"]:
            add_alert(alert)

        for alert_group, incoming_alerts in self.top['incoming_alert'].items():
            for alert in incoming_alerts:
                add_alert(alert, f'incoming_{alert_group}')

        if isinstance(alerts, RustEnum):
            alerts.add_number_of_variants("The number of Alert ID.")
        else:
            alerts.add_last_constant("The Last Valid Alert ID.")

        self.alert_sources = sources
        self.alert_alerts = alerts
        self.alert_mapping = alert_mapping

    def _init_pinmux_mapping(self):
        """Generate Rust enums for addressing pinmux registers and in/out selects.

        Inputs/outputs are connected in the order the modules are listed in
        the hjson under the "mio_modules" key. For each module, the
        corresponding inouts are connected first, followed by either the inputs
        or the outputs.

        Inputs:
        - Peripheral chooses register field (pinmux_peripheral_in)
        - Insel chooses MIO input (pinmux_insel)

        Outputs:
        - MIO chooses register field (pinmux_mio_out)
        - Outsel chooses peripheral output (pinmux_outsel)

        Insel and outsel have some special values which are captured here too.
        """
        pinmux_info = self.top['pinmux']
        pinout_info = self.top['pinout']

        # Peripheral Inputs
        peripheral_in = self._enum_type(self._top_name,
                                        Name(['pinmux', 'peripheral', 'in']),
                                        self.regwidth)
        i = 0
        for sig in pinmux_info['ios']:
            if sig['connection'] == 'muxed' and sig['type'] in [
                    'inout', 'input'
            ]:
                index = Name([str(sig['idx'])]) if sig['idx'] != -1 else Name(
                    [])
                name = Name.from_snake_case(sig['name']) + index
                peripheral_in.add_constant(
                    name, docstring='Peripheral Input {}'.format(i))
                i += 1

        if isinstance(peripheral_in, RustEnum):
            peripheral_in.add_number_of_variants('Number of peripheral input')
        else:
            peripheral_in.add_last_constant('Last valid peripheral input')

        # Pinmux Input Selects
        insel = self._enum_type(self._top_name, Name(['pinmux', 'insel']),
                                self.regwidth)
        insel.add_constant(Name(['constant', 'zero']),
                           docstring='Tie constantly to zero')
        insel.add_constant(Name(['constant', 'one']),
                           docstring='Tie constantly to one')
        i = 0
        for pad in pinout_info['pads']:
            if pad['connection'] == 'muxed':
                insel.add_constant(Name([pad['name']]),
                                   docstring='MIO Pad {}'.format(i))
                i += 1
        if isinstance(insel, RustEnum):
            insel.add_number_of_variants('Number of valid insel value')
        else:
            insel.add_last_constant('Last valid insel value')
        # MIO Outputs
        mio_out = self._enum_type(self._top_name,
                                  Name(['pinmux', 'mio', 'out']))
        i = 0
        for pad in pinout_info['pads']:
            if pad['connection'] == 'muxed':
                mio_out.add_constant(Name.from_snake_case(pad['name']),
                                     docstring='MIO Pad {}'.format(i))
                i += 1
        if isinstance(mio_out, RustEnum):
            mio_out.add_number_of_variants('Number of valid mio output')
        else:
            mio_out.add_last_constant('Last valid mio output')

        # Pinmux Output Selects
        outsel = self._enum_type(self._top_name, Name(['pinmux', 'outsel']),
                                 self.regwidth)
        outsel.add_constant(Name(['constant', 'zero']),
                            docstring='Tie constantly to zero')
        outsel.add_constant(Name(['constant', 'one']),
                            docstring='Tie constantly to one')
        outsel.add_constant(Name(['constant', 'high', 'z']),
                            docstring='Tie constantly to high-Z')
        i = 0
        for sig in pinmux_info['ios']:
            if sig['connection'] == 'muxed' and sig['type'] in [
                    'inout', 'output'
            ]:
                index = Name([str(sig['idx'])]) if sig['idx'] != -1 else Name(
                    [])
                name = Name.from_snake_case(sig['name']) + index
                outsel.add_constant(name,
                                    docstring='Peripheral Output {}'.format(i))
                i += 1

        if isinstance(outsel, RustEnum):
            outsel.add_number_of_variants('Number of valid outsel value')
        else:
            outsel.add_last_constant('Last valid outsel value')

        self.pinmux_peripheral_in = peripheral_in
        self.pinmux_insel = insel
        self.pinmux_mio_out = mio_out
        self.pinmux_outsel = outsel

    def _init_pad_mapping(self):
        """Generate Rust enums for order of MIO and DIO pads.

        These are needed to configure pad specific configurations such as
        slew rate and other flags.
        """
        direct_enum = self._enum_type(self._top_name, Name(["direct", "pads"]))
        muxed_enum = self._enum_type(self._top_name, Name(["muxed", "pads"]))

        pads_info = self.top['pinout']['pads']
        muxed = [
            pad['name'] for pad in pads_info if pad['connection'] == 'muxed'
        ]

        # The logic here follows the sequence done in toplevel_pkg.sv.tpl.
        # The direct pads do not enumerate directly from the pinout like the
        # muxed ios.  Instead it follows a direction from the pinmux
        # perspective.
        pads_info = self.top['pinmux']['ios']
        direct = [pad for pad in pads_info if pad['connection'] != 'muxed']

        for pad in (direct):
            name = f"{pad['name']}"
            if pad['width'] > 1:
                name = f"{name}{pad['idx']}"

            direct_enum.add_constant(Name.from_snake_case(name))
        if isinstance(direct_enum, RustEnum):
            direct_enum.add_number_of_variants("Number of valid direct pad")
        else:
            direct_enum.add_last_constant("Last valid direct pad")

        for pad in (muxed):
            muxed_enum.add_constant(Name.from_snake_case(pad))
        if isinstance(muxed_enum, RustEnum):
            muxed_enum.add_number_of_variants("Number of valid muxed pad")
        else:
            muxed_enum.add_last_constant("Last valid muxed pad")

        self.direct_pads = direct_enum
        self.muxed_pads = muxed_enum

    def _init_pwrmgr_wakeups(self):
        enum = self._enum_type(self._top_name,
                               Name(["power", "manager", "wake", "ups"]))

        for signal in self.top["wakeups"]:
            enum.add_constant(
                Name.from_snake_case(signal["module"]) +
                Name.from_snake_case(signal["name"]))

        if isinstance(enum, RustEnum):
            enum.add_number_of_variants("Number of valid pwrmgr wakeup signal")
        else:
            enum.add_last_constant("Last valid pwrmgr wakeup signal")

        self.pwrmgr_wakeups = enum

    # Enumerates the positions of all software controllable resets
    def _init_rstmgr_sw_rsts(self):
        sw_rsts = [r.name for r in self.top['resets'].get_sw_resets()]

        enum = self._enum_type(self._top_name,
                               Name(["reset", "manager", "sw", "resets"]))

        for rst in sw_rsts:
            enum.add_constant(Name.from_snake_case(rst))

        if isinstance(enum, RustEnum):
            enum.add_number_of_variants(
                "Number of valid rstmgr software reset request")
        else:
            enum.add_last_constant("Last valid rstmgr software reset request")

        self.rstmgr_sw_rsts = enum

    def _init_pwrmgr_reset_requests(self):
        enum = self._enum_type(self._top_name,
                               Name(["power", "manager", "reset", "requests"]))

        for signal in self.top["reset_requests"]["peripheral"]:
            enum.add_constant(
                Name.from_snake_case(signal["module"]) +
                Name.from_snake_case(signal["name"]))

        if isinstance(enum, RustEnum):
            enum.add_number_of_variants(
                "Number of valid pwrmgr reset_request signal")
        else:
            enum.add_last_constant("Last valid pwrmgr reset_request signal")

        self.pwrmgr_reset_requests = enum

    def _init_clkmgr_clocks(self):
        """
        Creates RustEnums for accessing the software-controlled clocks in the
        design.

        The logic here matches the logic in topgen.py in how it instantiates the
        clock manager with the described clocks.

        We differentiate "gateable" clocks and "hintable" clocks because the
        clock manager has separate register interfaces for each group.
        """
        clocks = self.top['clocks']

        gateable_clocks = self._enum_type(self._top_name,
                                          Name(["gateable", "clocks"]))
        hintable_clocks = self._enum_type(self._top_name,
                                          Name(["hintable", "clocks"]))

        c2g = clocks.make_clock_to_group()
        by_type = clocks.typed_clocks()

        for name in by_type.sw_clks.keys():
            # All these clocks start with `clk_` which is redundant.
            clock_name = Name.from_snake_case(name).remove_part("clk")
            docstring = "Clock {} in group {}".format(name, c2g[name].name)
            gateable_clocks.add_constant(clock_name, docstring)
        if isinstance(gateable_clocks, RustEnum):
            gateable_clocks.add_number_of_variants(
                "Number of Valid Gateable Clock")
        else:
            gateable_clocks.add_last_constant("Last Valid Gateable Clock")

        for name in by_type.hint_clks.keys():
            # All these clocks start with `clk_` which is redundant.
            clock_name = Name.from_snake_case(name).remove_part("clk")
            docstring = "Clock {} in group {}".format(name, c2g[name].name)
            hintable_clocks.add_constant(clock_name, docstring)
        if isinstance(hintable_clocks, RustEnum):
            hintable_clocks.add_number_of_variants(
                "Number of Valid Hintable Clock")
        else:
            hintable_clocks.add_last_constant("Last Valid Hintable Clock")

        self.clkmgr_gateable_clocks = gateable_clocks
        self.clkmgr_hintable_clocks = hintable_clocks

    def _init_subranges(self, addr_space_name: str):
        """
        Computes the bounds of all subspace regions of a given address space.
        """
        subspace_regions = []
        addr_space = get_addr_space(self.top, addr_space_name)
        for subspace in addr_space.get('subspaces', []):
            regions = []
            for node in subspace['nodes']:
                # Get the dot-delimited interface name. If no interface
                # name is given, all device interfaces are considered for
                # this subspace range.
                split_dev = node.rsplit('.', 1)
                dev_name = split_dev[0]
                if_name = None
                if len(split_dev) > 1:
                    if_name = split_dev[1]

                ranges = get_device_ranges(self.devices(addr_space_name),
                                           dev_name)
                if if_name:
                    # Only a single interface, if name contained an interface
                    # name
                    regions.append(ranges[if_name])
                else:
                    # All interfaces
                    regions += list(ranges.values())

            subspace_range = range(
                min([r.base_addr for r in regions]),
                max([r.base_addr + r.size_bytes for r in regions]))
            subspace_region = MemoryRegion(
                self._top_name, Name([subspace['name']]), addr_space_name,
                subspace_range.start,
                subspace_range.stop - subspace_range.start)
            subspace_regions.append(
                (subspace['name'], subspace['desc'], subspace_region))

        self.subranges[addr_space_name] = subspace_regions
