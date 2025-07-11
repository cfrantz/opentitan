# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import logging as log
import re
from collections import OrderedDict, defaultdict
from copy import deepcopy
from itertools import chain
from math import ceil, log2
from typing import Dict, List, Tuple, Union

from basegen.typing import ConfigT
from raclgen.lib import parse_racl_config, parse_racl_mapping
from reggen.ip_block import IpBlock
from reggen.params import (LocalParam, MemSizeParameter, Parameter,
                           RandParameter)
from reggen.validate import check_bool
from topgen import lib, secure_prng
from topgen.typing import IpBlocksT

from .clocks import Clocks, UnmanagedClocks
from .resets import Resets, UnmanagedResets


def _get_random_data_hex_literal(width):
    """ Fetch 'width' random bits and return them as hex literal"""
    width = int(width)
    literal_str = hex(secure_prng.getrandbits(width))
    return literal_str


def _get_random_perm_hex_literal(numel):
    """ Compute a random permutation of 'numel' elements and
    return as packed hex literal"""
    num_elements = int(numel)
    width = int(ceil(log2(num_elements)))
    idx = [x for x in range(num_elements)]
    secure_prng.shuffle(idx)
    literal_str = ""
    for k in idx:
        literal_str += format(k, '0' + str(width) + 'b')
    # convert to hex for space efficiency
    literal_str = hex(int(literal_str, 2))
    return literal_str


def elaborate_instances(top, name_to_block: IpBlocksT):
    '''Add additional fields to the elements of top['module']

    These elements represent instantiations of IP blocks. This function adds
    extra fields to them to carry across information from the IpBlock objects
    that represent the blocks being instantiated. See elaborate_instance for
    more details of what gets added.
    '''
    for instance in top['module']:
        block = name_to_block[instance['type']]
        elaborate_instance(instance, block)


def elaborate_instance(instance, block: IpBlock):
    """Add additional fields to a single instance of a module.

    instance is the instance to be filled in. block is the block that it's
    instantiating.

    Altered fields:
        - param_list (list of parameters for the instance)
        - inter_signal_list (list of inter-module signals)
        - base_addrs (a map from interface name to its base address)

    Removed fields:
        - base_addr (this is reflected in base_addrs)
    """
    # create an empty dict if nothing is there
    if "param_decl" not in instance:
        instance["param_decl"] = {}

    mod_name = instance["name"]
    cc_mod_name = lib.Name.from_snake_case(mod_name).as_camel_case()

    # Check to see if all declared parameters exist
    param_decl_accounting = [decl for decl in instance["param_decl"].keys()]

    # param_list
    new_params = []
    for param in block.params.by_name.values():
        if isinstance(param, LocalParam):
            # Remove local parameters.
            continue

        new_param = param.as_dict()

        param_expose = param.expose if isinstance(param, Parameter) else False

        # assign an empty entry if this is not present
        if "memory" not in instance:
            instance["memory"] = {}

        # Check for security-relevant parameters that are not exposed,
        # adding a top-level name.
        if param.name.lower().startswith("sec") and not param_expose:
            log.warning(f"{mod_name} has security-critical parameter "
                        f"{param.name} not exposed to top")

        # Move special prefixes to the beginning of the parameter name.
        param_prefixes = ["Sec", "RndCnst", "MemSize"]
        name_top = cc_mod_name + param.name
        for prefix in param_prefixes:
            if not param.name.startswith(prefix):
                continue
            else:
                if param.name == prefix:
                    raise ValueError(f'Module instance {mod_name} has a '
                                     f'parameter {param.name} that is equal '
                                     f'to prefix {prefix}.')

                if re.match(prefix + '[A-Z].+$', param.name):
                    name_top = (prefix + cc_mod_name +
                                param.name[len(prefix):])
                break

        new_param['name_top'] = name_top

        # Generate random bits or permutation, if needed
        if isinstance(param, RandParameter):
            if param.randtype == 'data':
                new_default = _get_random_data_hex_literal(param.randcount)
                # Effective width of the random vector
                randwidth = param.randcount
            else:
                assert param.randtype == 'perm'
                new_default = _get_random_perm_hex_literal(param.randcount)
                # Effective width of the random vector
                randwidth = param.randcount * ceil(log2(param.randcount))

            new_param['default'] = new_default
            new_param['randwidth'] = randwidth

        elif isinstance(param, MemSizeParameter):
            key = param.name[7:].lower()
            # Set the parameter to the specified memory size.
            if key in instance["memory"]:
                new_default = int(instance["memory"][key]["size"], 0)
                new_param['default'] = new_default
            else:
                log.error("Missing memory configuration for "
                          f"memory {key} in instance {instance['name']}")

        # if this exposed parameter is listed in the `param_decl` dict,
        # override its default value.
        elif param.name in instance["param_decl"].keys():
            new_param['default'] = instance["param_decl"][param.name]
            # remove the parameter from the accounting dict
            param_decl_accounting.remove(param.name)

        new_params.append(new_param)

    instance["param_list"] = new_params

    # for each module declaration, check to see that the parameter actually
    # exists and can be set
    for decl in param_decl_accounting:
        log.error("{} is not a valid parameter of {} that can be "
                  "set from top level".format(decl, block.name))

    # These objects get added-to in place by code in intermodule.py, so we have
    # to convert and copy them here.
    instance["inter_signal_list"] = [s.as_dict() for s in block.inter_signals]

    # If we have width-parametrized intersignal, we need to update the intersignal param name
    # the the instance mangled param name
    for s in instance["inter_signal_list"]:
        if isinstance(s['width'], Parameter):
            for p in instance["param_list"]:
                if p['name'] == s['width'].name:
                    # When mangling the name, we first need to deep copy the
                    # param. Parameters in signals have a reference to a
                    # parameter. If we have multiple instances of the same IP,
                    # then their signals would reference the same single
                    # parameter. If we would mangle that directly, we all
                    # signals of all IPs would reference to that single mangled
                    # parameter. Since parameters are instance dependent, that
                    # would fail. Therefore, copy the parameter first to have
                    # a unique parameter for that particular signal and
                    # instance, which is safe to mangle.
                    s['width'] = deepcopy(s['width'])
                    s['width'].name_top = p['name_top']

    # An instance must either have a 'base_addr' address or a 'base_addrs'
    # address, but can't have both.
    base_addrs = instance.get('base_addrs')
    if base_addrs is None:
        if 'base_addr' not in instance:
            raise ValueError('Instance {!r} has neither a base_addr '
                             'nor a base_addrs field.'.format(
                                 instance['name']))
        else:
            # If the instance has a base_addr field, make sure that the block
            # has just one device interface.
            if len(block.reg_blocks) != 1:
                raise ValueError('Instance {!r} has a base_addr field but it '
                                 'instantiates the block {!r}, which has {} '
                                 'device interfaces.'.format(
                                     instance['name'], block.name,
                                     len(block.reg_blocks)))
            else:
                if_name = next(iter(block.reg_blocks))
                base_addrs = {if_name: instance['base_addr']}

        # Fill in a bogus base address (we don't have proper error handling, so
        # have to do *something*)
        if base_addrs is None:
            base_addrs = {None: 0}

        instance['base_addrs'] = base_addrs
    else:
        if 'base_addr' in instance:
            log.error(f'Instance {instance["name"]} has both a base_addr '
                      'and a base_addrs field.')

        # Since the instance already has a base_addrs field, make sure that
        # it's got the same set of keys as the name of the interfaces in the
        # block.
        inst_if_names = set(base_addrs.keys())
        block_if_names = set(block.reg_blocks.keys())
        if block_if_names != inst_if_names:
            log.error('Instance {!r} has a base_addrs field with keys {} '
                      'but the block it instantiates ({!r}) has device '
                      'interfaces {}.'.format(instance['name'], inst_if_names,
                                              block.name, block_if_names))

    if 'base_addr' in instance:
        del instance['base_addr']

    # Default value if no value provided and otherwise convert string to bool
    if 'generate_dif' not in instance:
        instance['generate_dif'] = True
    else:
        converted_value, err = check_bool(instance['generate_dif'],
                                          'generate_dif')
        if err:
            raise ValueError('generate_dif contains invalid value '
                             f'{instance["generate_dif"]}')
        instance['generate_dif'] = converted_value

    # An instance can either have a 'racl_mapping' or 'racl_mappings' but
    # can't have both.
    # 'racl_mapping' is used when the device has a single register interface and
    # 'racl_mappings' when there are more. Translate to always use unified
    # racl_mappings entry.
    racl_mapping = instance.get('racl_mapping')
    if racl_mapping is not None:
        if instance.get('racl_mappings') is not None:
            raise ValueError(
                "Cannot specify both 'racl_mapping' and 'racl_mappings'")
        del instance['racl_mapping']
        instance['racl_mappings'] = {None: racl_mapping}


# TODO: Replace this part to be configurable from Hjson or template
predefined_modules = {"corei": "rv_core_ibex", "cored": "rv_core_ibex"}


def is_xbar(top, name):
    """Check if the given name is crossbar
    """
    xbars = list(filter(lambda node: node["name"] == name, top["xbar"]))
    if len(xbars) == 0:
        return False, None

    if len(xbars) > 1:
        log.error("Matching crossbar {} is more than one.".format(name))
        raise SystemExit()

    return True, xbars[0]


def xbar_addhost(top, xbar, host):
    """Add host nodes information

    - xbar: bool, true if the host port is from another Xbar
    """
    # Check and fetch host if exists in nodes
    obj = list(filter(lambda node: node["name"] == host, xbar["nodes"]))
    if len(obj) == 0:
        log.warning(
            "host %s doesn't exist in the node list. Using default values" %
            host)
        obj = OrderedDict([
            ("name", host),
            ("clock", xbar['clock']),
            ("reset", xbar['reset']),
            ("type", "host"),
            ("addr_space", xbar['addr_space']),
            ("inst_type", ""),
            ("stub", False),
            # The default matches RTL default
            ("pipeline", True),
            ("req_fifo_pass", True),
            ("rsp_fifo_pass", True)
        ])
        xbar["nodes"].append(obj)
        return

    xbar_bool, _xbar_h = is_xbar(top, host)
    if xbar_bool:
        log.info("host {} is a crossbar. Nothing to deal with.".format(host))

    obj[0]["xbar"] = xbar_bool

    if 'clock' not in obj[0]:
        obj[0]["clock"] = xbar['clock']

    if 'reset' not in obj[0]:
        obj[0]["reset"] = xbar["reset"]

    obj[0]["stub"] = False
    obj[0]["inst_type"] = predefined_modules[
        host] if host in predefined_modules else ""
    obj[0]["pipeline"] = obj[0]["pipeline"] if "pipeline" in obj[0] else True
    obj[0]["req_fifo_pass"] = obj[0]["req_fifo_pass"] if obj[0][
        "pipeline"] and "req_fifo_pass" in obj[0] else True
    obj[0]["rsp_fifo_pass"] = obj[0]["rsp_fifo_pass"] if obj[0][
        "pipeline"] and "rsp_fifo_pass" in obj[0] else True


def process_pipeline_var(node):
    """Add device nodes pipeline information

    - Supply a default of true / true if not defined by xbar
    """
    node["pipeline"] = node["pipeline"] if "pipeline" in node else True
    node["req_fifo_pass"] = node[
        "req_fifo_pass"] if "req_fifo_pass" in node else True
    node["req_fifo_pass"] = node[
        "req_fifo_pass"] if "req_fifo_pass" in node else True


def xbar_adddevice(top: ConfigT, name_to_block: IpBlocksT, xbar: ConfigT,
                   other_xbars: List[str], device: str) -> None:
    """Add or amend an entry in xbar['nodes'] to represent the device interface

    - clock: comes from module if exist, use xbar default otherwise
    - reset: comes from module if exist, use xbar default otherwise
    - inst_type: comes from module or memory if exist.
    - base_addr: comes from module or memory, or assume rv_plic?
    - size_byte: comes from module or memory
    - xbar: bool, true if the device port is another xbar
    - stub: There is no backing module / memory, instead a tlul port
            is created and forwarded above the current hierarchy
    """
    device_parts = device.split('.', 1)
    device_base = device_parts[0]
    device_ifname = device_parts[1] if len(device_parts) > 1 else None

    # Try to find a block or memory instance with name device_base. Object
    # names should be unique, so there should never be more than one hit.
    instances = [
        node for node in top["module"] + top["memory"]
        if node['name'] == device_base
    ]
    assert len(instances) <= 1
    inst = instances[0] if instances else None

    # Try to find a node in the crossbar called device. Node names should be
    # unique, so there should never be more than one hit.
    nodes = [node for node in xbar['nodes'] if node['name'] == device]
    assert len(nodes) <= 1
    node = nodes[0] if nodes else None

    log.info(
        "Handling xbar device {} (matches instance? {}; matches node? {})".
        format(device, inst is not None, node is not None))

    # case 1: another xbar --> check in xbar list
    if node is None and device in other_xbars:
        log.error(
            "Another crossbar %s needs to be specified in the 'nodes' list" %
            device)
        return

    # If there is no module or memory with the right name, this might still be
    # ok: we might be connecting to another crossbar or to a predefined module.
    if inst is None:
        # case 1: Crossbar handling
        if device in other_xbars:
            log.info(
                "device {} in Xbar {} is connected to another Xbar".format(
                    device, xbar["name"]))
            assert node is not None
            node["xbar"] = True
            node["stub"] = False
            process_pipeline_var(node)
            return

        # case 2: predefined_modules (debug_mem, rv_plic)
        # TODO: Find configurable solution not from predefined but from object?
        if device in predefined_modules:
            log.error("device %s shouldn't be host type" % device)

            return

        # case 3: not defined
        # Crossbar check
        log.error("Device %s doesn't exist in 'module', 'memory', predefined, "
                  "or as a node object" % device)
        return

    # If we get here, inst points an instance of some block or memory. It
    # shouldn't point at a crossbar (because that would imply a naming clash)
    assert device_base not in other_xbars
    base_addrs, size_byte = lib.get_base_and_size(name_to_block, inst,
                                                  device_ifname)
    addr_range = {
        "base_addrs":
        {asid: hex(base_addr)
         for (asid, base_addr) in base_addrs.items()},
        "size_byte": hex(size_byte),
    }

    stub = not lib.is_inst(inst)

    if node is None:
        log.error(f'Cannot connect to {repr(device)} because the crossbar '
                  f'defines no node for {repr(device_base)}.')
        return

    node["inst_type"] = inst["type"]
    node["addr_range"] = [addr_range]
    node["xbar"] = False
    node["stub"] = stub
    process_pipeline_var(node)


def amend_xbar(top: ConfigT, name_to_block: IpBlocksT, xbar: ConfigT):
    """Amend crossbar informations to the top list

    Amended fields
    - clock: Adopt from module clock if exists
    - inst_type: Module instance some module will be hard-coded
                 the tool searches module list and memory list then put here
    - base_addr: from top["module"]
    - size: from top["module"]
    """
    xbar_list = [x["name"] for x in top["xbar"]]
    if xbar["name"] not in xbar_list:
        log.info(
            "Xbar %s doesn't belong to the top %s. Check if the xbar doesn't need"
            % (xbar["name"], top["name"]))
        return

    topxbar = list(
        filter(lambda node: node["name"] == xbar["name"], top["xbar"]))[0]

    topxbar["connections"] = deepcopy(xbar["connections"])
    if "nodes" in xbar:
        topxbar["nodes"] = deepcopy(xbar["nodes"])
    else:
        topxbar["nodes"] = []

    addr_spaces = {
        x["addr_space"]
        for x in topxbar["nodes"] if "addr_space" in x
    }
    topxbar["addr_spaces"] = sorted(addr_spaces)

    # xbar primary clock and reset
    topxbar["clock"] = xbar["clock_primary"]
    topxbar["reset"] = xbar["reset_primary"]

    # Build nodes from 'connections'
    device_nodes = set()
    for host, devices in xbar["connections"].items():
        # add host first
        xbar_addhost(top, topxbar, host)

        # add device if doesn't exist
        device_nodes.update(devices)

    other_xbars = [x["name"] for x in top["xbar"] if x["name"] != xbar["name"]]

    log.info(device_nodes)
    for device in device_nodes:
        xbar_adddevice(top, name_to_block, topxbar, other_xbars, device)


def xbar_cross(xbar, xbars):
    """Check if cyclic dependency among xbars

    And gather the address range for device port (to another Xbar)

    @param node_name if not "", the function only search downstream
                     devices starting from the node_name
    @param visited   The nodes it visited to reach this port. If any
                     downstream port from node_name in visited, it means
                     circular path exists. It should be fatal error.
    """
    # Step 1: Visit devices (gather the address range)
    log.info("Processing circular path check for {}".format(xbar["name"]))
    addr = []
    for node in [
            x for x in xbar["nodes"]
            if x["type"] == "device" and "xbar" in x and x["xbar"] is False
    ]:
        addr.extend(node["addr_range"])

    # Step 2: visit xbar device ports
    xbar_nodes = [
        x for x in xbar["nodes"]
        if x["type"] == "device" and "xbar" in x and x["xbar"] is True
    ]

    # Now call function to get the device range
    # the node["name"] is used to find the host_xbar and its connection. The
    # assumption here is that there's only one connection from crossbar A to
    # crossbar B.
    #
    # device_xbar is the crossbar has a device port with name as node["name"].
    # host_xbar is the crossbar has a host port with name as node["name"].
    for node in xbar_nodes:
        (asid, xbar_addr) = xbar_cross_node(node["name"],
                                            xbar,
                                            xbars,
                                            visited=[])
        node["addr_space"] = asid
        # Filter addresses by ASID
        addr_range = []
        for addr in xbar_addr:
            if asid in addr["base_addrs"]:
                addr_range.append({
                    "base_addrs": {
                        asid: addr["base_addrs"][asid]
                    },
                    "size_byte": addr["size_byte"],
                })
        node["addr_range"] = addr_range


def xbar_cross_node(node_name: str,
                    device_xbar: ConfigT,
                    xbars: List[ConfigT],
                    visited=[],
                    asid=None):
    # 1. Get the connected xbar
    host_xbars = [x for x in xbars if x["name"] == node_name]
    assert len(host_xbars) == 1
    host_xbar = host_xbars[0]

    log.info("Processing node {} in Xbar {}.".format(node_name,
                                                     device_xbar["name"]))
    host_xbar_nodes = [
        x for x in host_xbar["nodes"] if x["name"] == device_xbar["name"]
    ]
    assert len(host_xbar_nodes) == 1
    host_xbar_node = host_xbar_nodes[0]
    host_xbar_asid = host_xbar_node["addr_space"]

    if asid is None:
        asid = host_xbar_asid
    assert asid == host_xbar_asid

    result = []  # [(base_addr, size), .. ]
    # Sweep the devices using connections and gather the address.
    # If the device is another xbar, call recursive
    visited.append(host_xbar["name"])
    devices = host_xbar["connections"][device_xbar["name"]]

    for node in host_xbar["nodes"]:
        if node["name"] not in devices:
            continue
        if "xbar" in node and node["xbar"] is True:
            if "addr_range" not in node:
                # Deeper dive into another crossbar
                (_asid, xbar_addr) = xbar_cross_node(node["name"], host_xbar,
                                                     xbars, visited, asid)
                node["addr_range"] = xbar_addr

        result.extend(deepcopy(node["addr_range"]))

    visited.pop()

    return (asid, result)


# find the first instance name of a given type
def _find_module_name(modules: Dict[str, ConfigT], module_type: str):
    for m in modules:
        if m['type'] == module_type:
            return m['name']

    return None


def _get_clock_group_name(clk: Union[str, OrderedDict],
                          default_ep_grp: str) -> Tuple[str, str]:
    """Return the clock group of a particular clock connection

    Checks whether there is a specific clock group associated with this
    connection and returns its name. If not, this returns the default clock
    group of the clock end point.
    """
    # If the value of a particular connection is a dict,
    # there are additional attributes to explore
    if isinstance(clk, str):
        group_name = default_ep_grp
        src_name = clk
    else:
        assert isinstance(clk, Dict)
        group_name = clk.get('group', default_ep_grp)
        src_name = clk['clock']

    return group_name, src_name


def is_unmanaged_clock(top: ConfigT, clock: str):
    return clock in top['unmanaged_clocks']._asdict()


def is_unmanaged_reset(top: ConfigT, reset: str):
    return reset in top['unmanaged_resets']


def extract_clocks(top: ConfigT):
    '''Add clock exports to top and connections to endpoints

    This function sets up all the clock-related machinery that is needed to
    generate the clkmgr code. This runs before we load up IP blocks with
    reggen, so can only see top-level configuration.

    By default each end point (peripheral, memory etc) is in the same clock
    group. However, it is possible to define the group attribute per clock
    if required.
    '''
    if not isinstance(top['clocks'], Clocks):
        top['clocks'] = Clocks(top['clocks'])
    clocks = top['clocks']
    if not isinstance(top['unmanaged_clocks'], UnmanagedClocks):
        top['unmanaged_clocks'] = UnmanagedClocks(top['unmanaged_clocks'])

    exported_clks = OrderedDict()

    for ep in top['module'] + top['memory'] + top['xbar']:
        clock_connections = OrderedDict()

        # Ensure each module has a default case
        export_if = ep.get('clock_reset_export', [])

        # The clock group attribute in an end point sets the default
        # group for every clock in that end point.
        #
        # However, the end point can also override specific clocks to
        # different groups inside clock_srcs.  This is generally not
        # recommended as it is better to stay consistent.  However
        # if needed, the method is available.
        ep['clock_group'] = 'secure' if 'clock_group' not in ep else ep[
            'clock_group']
        ep_grp = ep['clock_group']

        # end point names and clocks
        ep_name = ep['name']

        for port, clk in ep['clock_srcs'].items():
            group_name, src_name = _get_clock_group_name(clk, ep_grp)

            if is_unmanaged_clock(top, src_name):
                # Unmanaged clocks have a simpler connection without clock
                # groups
                clock_connections[port] = top['unmanaged_clocks']._asdict(
                )[src_name].signal_name
            else:
                group = clocks.groups[group_name]

                name = ''
                hier_name = clocks.hier_paths[group.src]

                if group.src == 'ext':
                    name = "{}_i".format(src_name)

                elif group.unique:
                    # new unique clock name
                    name = "{}_{}".format(src_name, ep_name)

                else:
                    # new group clock name
                    name = "{}_{}".format(src_name, group_name)

                clk_name = "clk_" + name

                # add clock to a particular group
                clk_sig = clocks.add_clock_to_group(group, clk_name, src_name)
                clk_sig.add_endpoint(ep_name, port)

                # add clock connections
                clock_connections[port] = hier_name + clk_name

                # clocks for this module are exported
                for intf in export_if:
                    log.info("{} export clock name is {}".format(
                        ep_name, name))

                    # create dict entry if it does not exit
                    if intf not in exported_clks:
                        exported_clks[intf] = OrderedDict()

                    # if first time encounter end point, declare
                    if ep_name not in exported_clks[intf]:
                        exported_clks[intf][ep_name] = []

                    # append clocks
                    exported_clks[intf][ep_name].append(name)

        # Add to endpoint structure
        ep['clock_connections'] = clock_connections

    # add entry to top level json
    top['exported_clks'] = exported_clks


def connect_clocks(top: ConfigT, name_to_block: IpBlocksT):
    clocks = top['clocks']
    assert isinstance(clocks, Clocks)

    # add entry to inter_module automatically
    clkmgr_name = _find_module_name(top["module"], "clkmgr")
    # If there is no clkmgr, nothing to do here
    if not clkmgr_name:
        return

    external = top['inter_module']['external']
    for intf in top['exported_clks']:
        external[f'{clkmgr_name}.clocks_{intf}'] = f"clks_{intf}"

    typed_clocks = clocks.typed_clocks()

    # Set up intermodule connections for idle clocks. Iterating over
    # hint_names() here ensures that we visit the clocks in the same order as
    # the code that generates the enumeration in clkmgr_pkg.sv: important,
    # since the order that we add entries to clkmgr_idle below gives the index
    # of each hint in the "idle" signal bundle. These *must* match, or we'll
    # have hard-to-debug mis-connections.
    clkmgr_idle = []
    for clk_name in typed_clocks.hint_names().keys():
        sig = typed_clocks.hint_clks[clk_name]
        ep_names = list(set(ep_name for ep_name, ep_port in sig.endpoints))
        if len(ep_names) != 1:
            raise ValueError(f'There are {len(ep_names)} end-points connected '
                             f'to the {sig.name} clock: {ep_names}. Where '
                             f'should the idle signal come from?')
        ep_name = ep_names[0]

        # We've got the name of the endpoint, but that's not enough: we need to
        # find the corresponding IpBlock. To do this, we have to do a (linear)
        # search through top['module'] to find the instance that matches the
        # endpoint, then use that instance's type as a key in name_to_block.
        ep_inst = lib.find_module(top["module"], ep_name)
        if ep_inst is None:
            raise ValueError(f'No module instance with name {ep_name}: only '
                             f'modules can have hint clocks. Is this a '
                             f'crossbar or a memory?')

        ip_block = name_to_block[ep_inst['type']]

        # Walk through the clocking items for the block to find the one that
        # defines each of the ports.
        idle_signal = None
        for ep_name, ep_port in sig.endpoints:
            ep_idle = None
            for item in ip_block.clocking.items:
                if item.clock != ep_port:
                    continue
                if item.idle is None:
                    raise ValueError(f'Cannot connect the {sig.name} clock to '
                                     f'port {ep_port} of {ep_name}. This is a '
                                     f'hint clock, but the clocking item on '
                                     f'the module defines no idle signal.')
                if idle_signal is not None and item.idle != idle_signal:
                    raise ValueError(f'Cannot connect the {sig.name} clock to '
                                     f'port {ep_port} of {ep_name}. We '
                                     f'already have a connection to another '
                                     f'clock signal which has an assocated '
                                     f'idle signal called {idle_signal}, but '
                                     f'this clocking item has an idle signal '
                                     f'called {item.idle}.')
                ep_idle = item.idle
                break
            if ep_idle is None:
                raise ValueError(f'Cannot connect the {sig.name} clock to '
                                 f'port {ep_port} of {ep_name}: no such '
                                 f'clocking item.')
            idle_signal = ep_idle
        assert idle_signal is not None

        # At this point, there's a slight problem: we use names like "idle_o"
        # for signals in the hjson, but the inter-module list expects names
        # like "idle". Drop the trailing "_o".
        if not idle_signal.endswith('_o'):
            raise ValueError(f'Idle signal for {ep_port} of {ep_name} is '
                             f'{idle_signal}, which is missing the expected '
                             f'"_o" suffix.')
        idle_signal = idle_signal[:-2]

        clkmgr_idle.append(ep_name + '.' + idle_signal)

    top['inter_module']['connect']['{}.idle'.format(clkmgr_name)] = clkmgr_idle


def amend_resets(top: ConfigT,
                 name_to_block: IpBlocksT,
                 allow_missing_blocks=False):
    """Generate exported reset structure and automatically connect to
    intermodule.

    Also iterate through and determine need for shadowed reset and
    domains.
    """
    unmanaged_resets = top.get('unmanaged_resets')
    if not unmanaged_resets:
        top['unmanaged_resets'] = UnmanagedResets([])
    elif not isinstance(unmanaged_resets, UnmanagedResets):
        top['unmanaged_resets'] = UnmanagedResets(unmanaged_resets)
    top_resets = (top['resets'] if isinstance(top['resets'], Resets) else
                  Resets(top['resets'], top['clocks']))
    rstmgr_name = _find_module_name(top['module'], 'rstmgr')

    # Generate exported reset list
    exported_rsts = OrderedDict()
    for module in top["module"]:
        block = name_to_block.get(module['type'])
        if block is None and allow_missing_blocks:
            continue
        block_clock = block.get_primary_clock()
        primary_reset = module['reset_connections'][block_clock.reset]

        # shadowed determination
        if block.has_shadowed_reg():
            # External unmanaged resets are don't have a shadowed reset.
            # Both the primary and and the shadowed reset are served from
            # the same reset signal. It is assumed that the external reset
            # is stable and free from glitches. Here, don't mark the reset
            # as shadowed to avoid generating a second reset signal.
            if not is_unmanaged_reset(top, primary_reset['name']):
                top_resets.mark_reset_shadowed(primary_reset['name'])

        log.info("in module {}".format(module["name"]))
        for r in block.clocking.items:
            if r.reset:
                reset = module['reset_connections'][r.reset]
                if is_unmanaged_reset(top, reset['name']):
                    continue
                top_resets.add_reset_domain(reset['name'], reset['domain'])

        # This code is here to ensure if amend_clocks/resets switched order
        # everything would still work
        export_if = module.get('clock_reset_export', [])

        # There may be multiple export interfaces
        for intf in export_if:
            # create dict entry if it does not exit
            if intf not in exported_rsts:
                exported_rsts[intf] = OrderedDict()

            # grab directly from reset_connections definition
            rsts = [rst for rst in module['reset_connections'].values()]
            exported_rsts[intf][module['name']] = rsts

    # ensure xbar resets are also covered.
    # unless otherwise stated, xbars always fall into the default power domain.
    for xbar in top["xbar"]:
        for reset in xbar['reset_connections'].values():
            if is_unmanaged_reset(top, reset['name']):
                continue
            top_resets.add_reset_domain(reset['name'], top['power']['default'])

    # add entry to top level json
    top['exported_rsts'] = exported_rsts

    # add entry to inter_module automatically
    if rstmgr_name is None and allow_missing_blocks:
        pass
    else:
        for intf in top['exported_rsts']:
            top['inter_module']['external'][f'{rstmgr_name}.resets_{intf}'] = (
                "rsts_{}".format(intf))

    # reset class objects
    top["resets"] = top_resets


def get_alerts_with_unique_lpg_idx(incoming_alerts: List[Dict]):
    unique_lpgs = set()
    result = []

    for alert in incoming_alerts:
        if alert['lpg_idx'] not in unique_lpgs:
            unique_lpgs.add(alert['lpg_idx'])
            result.append(alert)
    return result


def create_alert_lpgs(top: ConfigT, name_to_block: IpBlocksT):
    '''Loop over modules and determine number of unique LPGs'''
    lpg_dict = {}
    outgoing_lpg_dict = defaultdict(dict)
    top['alert_lpgs'] = []
    top['outgoing_alert_lpgs'] = defaultdict(list)

    # ensure the object is already generated before we attempt to use it
    assert isinstance(top['clocks'], Clocks)
    clock_groups = top['clocks'].make_clock_to_group()
    for module in top["module"]:
        # the alert senders are attached to the primary clock of this block,
        # so let's start by getting that primary clock port of an IP (we need
        # that to look up the clock connection at the top-level).
        block = name_to_block[module['type']]
        block_clock = block.get_primary_clock()
        primary_reset = module['reset_connections'][block_clock.reset]

        # for the purposes of alert handler LPGs, we need to know:
        #   1) the clock group of the primary clock
        #   2) the primary reset name
        #   3) the domain of the primary reset
        #
        # 1) figure out the clock group assignment of the primary clock
        # Get the full clock name and split the hierarchy path, getting the
        # last element
        clk = module['clock_connections'][block_clock.clock]
        # Unmanaged clocks are not part of the LPGs. Unmanaged clocks have the
        # input signal identifier ('_i') directly in the signal name. Determine
        # if that clock name is an
        # unmanaged clock
        unmanaged_clock = False
        for clock in top['unmanaged_clocks']._asdict().values():
            if clock.signal_name == clk:
                unmanaged_clock = True
                break

        # 2-3) get reset info
        reset_name = primary_reset['name']
        reset_domain = primary_reset['domain']

        if unmanaged_clock:
            lpg_name = '_'.join([clk, reset_name, reset_domain])
            unique_cg = False
        else:
            clk = clk.split(".")[-1]

            # Discover what clock group we are related to
            clock_group = clock_groups[clk]

            # using this info, we can create an LPG identifier
            # and uniquify it via a dict.
            lpg_name = '_'.join([clock_group.name, reset_name, reset_domain])
            unique_cg = clock_group.unique and clock_group.sw_cg != "no"

        # if clock group is "unique", add some uniquification to the tag
        lpg_name = f"{module['name']}_{lpg_name}" if unique_cg else lpg_name

        def append_to_lpg_dict(lpg_dict):
            # since the alert handler can tolerate timing delays on LPG
            # indication signals, we can just use the clock / reset signals
            # of the first block that belongs to a new unique LPG.
            clock = module['clock_connections'][block_clock.clock]
            lpg_dict.append({
                'name':
                lpg_name,
                'clock_group':
                None if unmanaged_clock else clock_group,
                'clock_connection':
                clock,
                'unmanaged_clock':
                unmanaged_clock,
                'unmanaged_reset':
                is_unmanaged_reset(top, reset_name),
                'reset_connection':
                primary_reset
            })

        alert_group = module.get('outgoing_alert')
        if alert_group is not None:
            if lpg_name not in outgoing_lpg_dict[alert_group]:
                outgoing_lpg_dict[alert_group][lpg_name] = len(
                    outgoing_lpg_dict[alert_group])
                append_to_lpg_dict(top['outgoing_alert_lpgs'][alert_group])
        else:
            if lpg_name not in lpg_dict:
                lpg_dict[lpg_name] = len(lpg_dict)
                append_to_lpg_dict(top['alert_lpgs'])

        # annotate all alerts of this module to use this LPG
        for alert in top['alert']:
            if alert['module_name'] == module['name']:
                alert['lpg_name'] = lpg_name
                alert['lpg_idx'] = lpg_dict[lpg_name]
        for alert_group, alerts in top['outgoing_alert'].items():
            for alert in alerts:
                if alert['module_name'] == module['name']:
                    alert['lpg_name'] = lpg_name
                    alert['lpg_idx'] = outgoing_lpg_dict[
                        module['outgoing_alert']][lpg_name]


def get_interrupt_modules(top: ConfigT,
                          name_to_block: IpBlocksT,
                          allow_missing_blocks=False) -> List[str]:
    """Return an existing top["interrupt_module"] or generate one.

    If the config has an "interrupt_module" it is taken as the true list
    of modules that will connect their interrupts to rv_plic. This allows
    some configs where some modules have their interrupts handled in
    more custom ways.

    When "interrupt_module" is not in the config the list is generated with
    all modules that have some interrupts and no "outgoing_interrupt".
    """
    if "interrupt_module" in top:
        return top["interrupt_module"]

    modules = []
    for module in top["module"]:
        block = name_to_block.get(module["type"])
        if block is None and allow_missing_blocks:
            continue
        if block.interrupts:
            if "outgoing_interrupt" not in module:
                modules.append(module["name"])

    return modules


def commit_interrupt_modules(top: ConfigT, name_to_block: IpBlocksT):
    """Ensure top['interrupt_module'] is populated in the final config."""
    top['interrupt_module'] = get_interrupt_modules(top, name_to_block)


def get_outgoing_interrupt_modules(top: ConfigT,
                                   name_to_block: IpBlocksT,
                                   allow_missing_blocks=False) -> List[str]:
    """Return an existing top["outgoing_interrupt_module"] or generate one.

    If the config has an "outgoing_interrupt_module" entry it is taken as the
    true list of modules that will send their interrupts out of this top. This
    allows some interrupts to be handled in some other top.

    When "outgoing_interrupt_module" is not in the config the list is generated
    with all modules that have some outgoing interrupt.
    """
    if "outgoing_interrupt_module" in top:
        return top["outgoing_interrupt_module"]

    modules = defaultdict(list)
    for module in top["module"]:
        block = name_to_block.get(module["type"])
        if block is None and allow_missing_blocks:
            continue
        if block.interrupts:
            if "outgoing_interrupt" in module:
                modules[module["outgoing_interrupt"]].append(module["name"])

    return modules


def commit_outgoing_interrupt_modules(top: ConfigT, name_to_block: IpBlocksT):
    """Ensure top["outgoing_interrupt_module"] is populated in the final config."""
    top["outgoing_interrupt_module"] = get_outgoing_interrupt_modules(top, name_to_block)


def amend_interrupt(top: ConfigT,
                    name_to_block: IpBlocksT,
                    allow_missing_blocks=False):
    modules = get_interrupt_modules(top, name_to_block, allow_missing_blocks)
    outgoing_modules = get_outgoing_interrupt_modules(top, name_to_block,
                                                      allow_missing_blocks)

    if "interrupt" not in top or top["interrupt"] == "":
        top["interrupt"] = []

    # Careful, "interrupt*s*"
    default_plic = None
    if "interrupts" in top and "default_plic" in top["interrupts"]:
        default_plic = top["interrupts"]["default_plic"]

    interrupts = []
    outgoing_interrupts = defaultdict(list)
    for m in modules + list(chain(*outgoing_modules.values())):
        ips = list(filter(lambda module: module["name"] == m, top["module"]))
        if len(ips) == 0:
            log.warning(
                "Cannot find IP %s which is used in the interrupt_module" % m)
            continue

        ip = ips[0]
        block = name_to_block[ip['type']]

        log.info("Adding interrupts from module %s" % ip["name"])
        for signal in block.interrupts:
            sig_dict = signal.as_nwt_dict('interrupt')
            qual = lib.add_module_prefix_to_signal(sig_dict, module=m.lower())
            sig_name = sig_dict["name"]
            qual["desc"] = f"{m} {sig_name} interrupt"
            qual["intr_type"] = signal.intr_type
            qual["default_val"] = signal.default_val
            qual["incoming"] = False
            plic = ip.get("plic", default_plic)
            if plic is not None:
                qual["plic"] = plic
            if "outgoing_interrupt" in ip:
                outgoing_interrupts[ip["outgoing_interrupt"]].append(qual)
                qual["outgoing"] = True
            else:
                interrupts.append(qual)
                qual["outgoing"] = False

    for irqs in top['incoming_interrupt'].values():
        for irq in irqs:
            # Qualify name with module name
            qual_irq = deepcopy(irq)
            qual_irq["name"] = f"{irq['module_name']}_{irq['name']}"
            qual_irq["desc"] = (f"{irq['module_name']} {irq['name']} "
                                "incoming interrupt")
            qual_irq["incoming"] = True
            qual_irq["width"] = 1
            # Incoming interrupts are assigned to the default PLIC
            qual_irq["plic"] = default_plic  # May still be None
            qual_irq["outgoing"] = False
            interrupts.append(qual_irq)

    top["interrupt"] = interrupts
    top["outgoing_interrupt"] = outgoing_interrupts


def get_alert_modules(top: ConfigT,
                      name_to_block: IpBlocksT,
                      allow_missing_blocks=False) -> List[str]:
    '''Return an existing top['alert_module'] or generate one.

    If the config has an 'alert_module' entry it is taken as the true list
    of modules that will send their alerts to alert_handler. This allows
    some configs where modules not in the list have their alerts handled
    in more custom ways.

    When 'alert_module' is not in the config the list is generated with
    all modules that have some alert and no 'outgoing_alert' but is not
    committed in the config. It will be done as a final step once the
    top config is fully generated.
    '''
    if 'alert_module' in top:
        return top['alert_module']

    modules = []
    for module in top['module']:
        block = name_to_block.get(module['type'])
        if block is None and allow_missing_blocks:
            continue
        if block.alerts:
            if 'outgoing_alert' not in module:
                modules.append(module['name'])

    return modules


def commit_alert_modules(top: ConfigT, name_to_block: IpBlocksT):
    """Make sure top['alert_module'] is populated in the final config."""
    top['alert_module'] = get_alert_modules(top, name_to_block)


def get_outgoing_alert_modules(top: ConfigT,
                               name_to_block: IpBlocksT,
                               allow_missing_blocks=False) -> List[str]:
    '''Return an existing top['outgoing_alert_module'] or generate one.

    If the config has an 'outgoing_alert_module' entry it is taken as the
    true list of modules that will send their alerts out of this top. This
    allows some alerts to be handled by an alert_handler in some other top.

    When 'outgoing_alert_module' is not in the config the list is generated
    with all modules that have some outgoing alert.
    '''
    if 'outgoing_alert_module' in top:
        return top['outgoing_alert_module']

    modules = defaultdict(list)
    for module in top['module']:
        block = name_to_block.get(module['type'])
        if block is None and allow_missing_blocks:
            continue
        if block.alerts:
            if 'outgoing_alert' in module:
                modules[module['outgoing_alert']].append(module['name'])

    return modules


def commit_outgoing_alert_modules(top: ConfigT, name_to_block: IpBlocksT):
    """Ensure top['outgoing_alert_module'] is populated in the final config."""
    top['outgoing_alert_module'] = get_outgoing_alert_modules(
        top, name_to_block)


def amend_alert(top: ConfigT,
                name_to_block: IpBlocksT,
                allow_missing_blocks=False):
    """Check alert_module if exists, or just use all modules
    """
    alert_modules = get_alert_modules(top, name_to_block, allow_missing_blocks)
    outgoing_modules = get_outgoing_alert_modules(top, name_to_block,
                                                  allow_missing_blocks)

    if "alert" not in top or top["alert"] == "":
        top["alert"] = []

    alerts = []
    outgoing_alerts = defaultdict(list)
    missing_ips = []

    for m in alert_modules + list(chain(*outgoing_modules.values())):
        ips = list(filter(lambda module: module["name"] == m, top["module"]))
        if len(ips) == 0:
            missing_ips.append(m)
            continue

        ip = ips[0]
        block = name_to_block.get(ip['type'])
        if block is None and allow_missing_blocks:
            continue
        log.info("Adding alert from module %s" % ip["name"])
        # Note: we assume that all alerts are asynchronous in order to make the
        # design homogeneous and more amenable to DV automation and synthesis
        # constraint scripting.
        for alert in block.alerts:
            alert_dict = alert.as_nwt_dict('alert')
            alert_dict['async'] = '1'
            qual_sig = lib.add_module_prefix_to_signal(alert_dict,
                                                       module=m.lower())
            alert_name = alert_dict['name']
            qual_sig['desc'] = f'{m} {alert_name} alert'
            if 'outgoing_alert' in ip:
                outgoing_alerts[ip['outgoing_alert']].append(qual_sig)
            else:
                alerts.append(qual_sig)
    if missing_ips:
        raise SystemExit(
            "The following IPs contributing alerts cannot be found: "
            ", ".join(missing_ips))

    top["alert"] = alerts
    top["outgoing_alert"] = outgoing_alerts


def amend_wkup(topcfg: ConfigT,
               name_to_block: IpBlocksT,
               allow_missing_blocks=False):

    if "wakeups" not in topcfg or topcfg["wakeups"] == "":
        topcfg["wakeups"] = []

    # create list of wakeup signals
    wakeups = []
    for m in topcfg["module"]:
        block = name_to_block.get(m['type'])
        if block is None and allow_missing_blocks:
            continue
        for signal in block.wakeups:
            log.info("Adding wakeup signal %s from module %s", signal.name,
                     m["name"])
            wakeups.append({
                'name': signal.name,
                'width': str(signal.bits.width()),
                'module': m["name"]
            })
    topcfg["wakeups"] = wakeups

    pwrmgr_name = _find_module_name(topcfg['module'], 'pwrmgr')
    if pwrmgr_name:
        # add wakeup signals to pwrmgr connections if there is one
        signal_names = [
            f"{s['module'].lower()}.{s['name'].lower()}"
            for s in topcfg["wakeups"]
        ]
        topcfg["inter_module"]["connect"][f"{pwrmgr_name}.wakeups"] = (
            signal_names)
        log.info("Intermodule signals: {}".format(
            topcfg["inter_module"]["connect"]))


# Handle reset requests from modules
def amend_reset_request(topcfg: ConfigT,
                        name_to_block: IpBlocksT,
                        allow_missing_blocks=False):
    if "reset_requests" not in topcfg or topcfg["reset_requests"] == "":
        topcfg["reset_requests"] = {}
    topcfg["reset_requests"].setdefault("peripheral", [])

    # create list of reset signals
    reset_signals = []
    for m in topcfg["module"]:
        log.info("Adding reset requests from module %s" % m["name"])
        block = name_to_block.get(m['type'])
        if block is None and allow_missing_blocks:
            continue
        for signal in block.reset_requests:
            log.info("Adding signal %s" % signal.name)
            reset_signals.append({
                'name': signal.name,
                'width': str(signal.bits.width()),
                'module': m["name"],
                'desc': signal.desc
            })
    topcfg["reset_requests"]["peripheral"] = reset_signals

    pwrmgr_name = _find_module_name(topcfg['module'], 'pwrmgr')
    if pwrmgr_name:
        # add reset requests to pwrmgr connections if there is one
        signal_names = [
            "{}.{}".format(s["module"].lower(), s["name"].lower())
            for s in topcfg["reset_requests"]["peripheral"]
        ]
        topcfg["inter_module"]["connect"][f"{pwrmgr_name}.rstreqs"] = (
            signal_names)
    log.info("Intermodule signals: {}".format(
        topcfg["inter_module"]["connect"]))


def append_io_signal(temp: ConfigT, sig_inst: Dict) -> None:
    '''Appends the signal to the correct list'''
    if sig_inst['type'] == 'inout':
        temp['inouts'].append(sig_inst)
    if sig_inst['type'] == 'input':
        temp['inputs'].append(sig_inst)
    if sig_inst['type'] == 'output':
        temp['outputs'].append(sig_inst)


def get_index_and_incr(ctrs: Dict, connection: str, io_dir: str) -> Dict:
    '''Get correct index counter and increment'''

    if connection != 'muxed':
        connection = 'dedicated'

    if io_dir in 'inout':
        result = ctrs[connection]['inouts']
        ctrs[connection]['inouts'] += 1
    elif connection == 'muxed':
        # For MIOs, the input/output arrays differ in RTL
        # I.e., the input array contains {inputs, inouts}, whereas
        # the output array contains {outputs, inouts}.
        if io_dir == 'input':
            result = ctrs[connection]['inputs'] + ctrs[connection]['inouts']
            ctrs[connection]['inputs'] += 1
        elif io_dir == 'output':
            result = ctrs[connection]['outputs'] + ctrs[connection]['inouts']
            ctrs[connection]['outputs'] += 1
        else:
            assert (0)  # should not happen
    else:
        # For DIOs, the input/output arrays are identical in terms of index
        # layout. Unused inputs are left unconnected and unused outputs are
        # tied off.
        if io_dir == 'input':
            result = ctrs[connection]['inputs'] + ctrs[connection]['inouts']
            ctrs[connection]['inputs'] += 1
        elif io_dir == 'output':
            result = (ctrs[connection]['outputs'] +
                      ctrs[connection]['inouts'] + ctrs[connection]['inputs'])
            ctrs[connection]['outputs'] += 1
        else:
            assert (0)  # should not happen

    return result


def amend_pinmux_io(top: ConfigT,
                    name_to_block: IpBlocksT,
                    allow_missing_blocks=False):
    """Process pinmux/pinout configuration and assign available IOs
    """
    pinmux = top['pinmux']
    pinout = top['pinout']
    targets = top['targets']

    temp = {}
    temp['inouts'] = []
    temp['inputs'] = []
    temp['outputs'] = []

    for sig in pinmux['signals']:
        # Get the signal information from the IP block type of this instance/
        mod_name = sig['instance']
        m = lib.get_module_by_name(top, mod_name)

        if m is None:
            raise SystemExit("Module {} is not searchable.".format(mod_name))

        block = name_to_block.get(m['type'])
        if block is None and allow_missing_blocks:
            continue
        sig_attr = sig.get('attr', 'BidirStd')
        # If the signal is explicitly named.
        if sig['port'] != '':

            # If this is a bus signal with explicit indexes.
            if '[' in sig['port']:
                name_split = sig['port'].split('[')
                sig_name = name_split[0]
                idx = int(name_split[1][:-1])
            else:
                idx = -1
                sig_name = sig['port']

            sig_inst = deepcopy(block.get_signal_by_name_as_dict(sig_name))

            if idx >= 0 and idx >= sig_inst['width']:
                raise SystemExit(f"Index {idx} is out of bounds for signal "
                                 f"{sig_name} with width "
                                 "{}.".format(sig_inst['width']))
            if idx == -1 and sig_inst['width'] != 1:
                raise SystemExit(f"Bus signal {sig_name} requires an index.")

            # If we got this far we know that the signal is valid and exists.
            # Augment this signal instance with additional information.
            sig_inst.update({
                'idx': idx,
                'pad': sig['pad'],
                'attr': sig_attr,
                'connection': sig['connection'],
                'desc': sig['desc']
            })
            sig_inst['name'] = mod_name + '_' + sig_inst['name']
            append_io_signal(temp, sig_inst)

        # Otherwise the name is a wildcard for selecting all available IO
        # signals of this block and we need to extract them here one by one
        # signals here.
        else:
            sig_list = deepcopy(block.get_signals_as_list_of_dicts())

            for sig_inst in sig_list:
                # If this is a multibit signal, unroll the bus and
                # generate a single bit IO signal entry for each one.
                if sig_inst['width'] > 1:
                    for idx in range(sig_inst['width']):
                        sig_inst_copy = deepcopy(sig_inst)
                        sig_inst_copy.update({
                            'idx': idx,
                            'pad': sig['pad'],
                            'attr': sig_attr,
                            'connection': sig['connection'],
                            'desc': sig['desc']
                        })
                        sig_inst_copy['name'] = sig[
                            'instance'] + '_' + sig_inst_copy['name']
                        append_io_signal(temp, sig_inst_copy)
                else:
                    sig_inst.update({
                        'idx': -1,
                        'pad': sig['pad'],
                        'attr': sig_attr,
                        'connection': sig['connection'],
                        'desc': sig['desc']
                    })
                    sig_inst['name'] = sig['instance'] + '_' + sig_inst['name']
                    append_io_signal(temp, sig_inst)

    # Now that we've collected all input and output signals,
    # we can go through once again and stack them into one unified
    # list, and calculate MIO/DIO global indices.
    pinmux['ios'] = (temp['inouts'] + temp['inputs'] + temp['outputs'])

    # Remember these counts to facilitate the RTL generation
    pinmux['io_counts'] = {
        'dedicated': {
            'inouts': 0,
            'inputs': 0,
            'outputs': 0,
            'pads': 0
        },
        'muxed': {
            'inouts': 0,
            'inputs': 0,
            'outputs': 0,
            'pads': 0
        }
    }

    for sig in pinmux['ios']:
        glob_idx = get_index_and_incr(pinmux['io_counts'], sig['connection'],
                                      sig['type'])
        sig['glob_idx'] = glob_idx

    # Calculate global indices for pads.
    j = k = 0
    for pad in pinout['pads']:
        if pad['connection'] == 'muxed':
            pad['idx'] = j
            j += 1
        else:
            pad['idx'] = k
            k += 1
    pinmux['io_counts']['muxed']['pads'] = j
    pinmux['io_counts']['dedicated']['pads'] = k

    # For each target configuration, calculate the special signal indices.
    known_muxed_pads = {}
    for pad in pinout['pads']:
        if pad['connection'] == 'muxed':
            known_muxed_pads[pad['name']] = pad

    known_mapped_dio_pads = {}
    for sig in pinmux['ios']:
        if sig['connection'] in ['muxed', 'manual']:
            continue
        if sig['pad'] in known_mapped_dio_pads:
            raise SystemExit(
                'Cannot have multiple IOs mapped to the same DIO pad {}'.
                format(sig['pad']))
        known_mapped_dio_pads[sig['pad']] = sig

    for target in targets:
        for entry in target['pinmux']['special_signals']:
            # If this is a muxed pad, the resolution is
            # straightforward. I.e., we just assign the MIO index.
            if entry['pad'] in known_muxed_pads:
                entry['idx'] = known_muxed_pads[entry['pad']]['idx']
            # Otherwise we need to find out which DIO this pad is mapped to.
            # Note that we can't have special_signals that are manual, since
            # there needs to exist a DIO connection.
            elif entry['pad'] in known_mapped_dio_pads:
                # This index refers to the stacked {dio, mio} array on the
                # chip-level, hence we have to add the amount of MIO pads.
                idx = (known_mapped_dio_pads[entry['pad']]['glob_idx'] +
                       pinmux['io_counts']['muxed']['pads'])
                entry['idx'] = idx
            else:
                assert (0)  # Entry should be guaranteed to exist at this point


def amend_racl(top_cfg: ConfigT,
               name_to_block: IpBlocksT,
               allow_missing_blocks=False):
    """Amend top_cfg based on racl configuration.

    Parse racl configuration and annotate individual modules affected.
    """
    if 'racl_config' not in top_cfg:
        return

    # Read the top-level RACL information
    top_cfg["racl"] = parse_racl_config(top_cfg["cfg_path"] /
                                        top_cfg["racl_config"])

    # Generate the RACL mappings for all subscribing IPs
    for m in top_cfg['module']:
        block = name_to_block.get(m['type'])
        if block is None and allow_missing_blocks:
            continue
        racl_mappings = m.get('racl_mappings', {})
        # Nothing to be done if there are no mappings or the mappings
        # were expanded already.
        # If racl_mappings is expanded the path is one of the fields
        for if_name, mapping_path in racl_mappings.items():
            if isinstance(mapping_path, dict):
                # The racl_mappings values are expanded in place into a dict
                # once and need no further updates.
                continue
            register_mapping, window_mapping, range_mapping, racl_group, _ = (
                parse_racl_mapping(top_cfg["racl"],
                                   top_cfg["cfg_path"] / mapping_path, if_name,
                                   block))
            m['racl_mappings'][if_name] = {
                'racl_group': racl_group,
                'register_mapping': register_mapping,
                'window_mapping': window_mapping,
                'range_mapping': range_mapping,
            }


def merge_top(topcfg: ConfigT, name_to_block: IpBlocksT,
              xbarobjs: OrderedDict) -> OrderedDict:

    # Combine ip cfg into topcfg
    elaborate_instances(topcfg, name_to_block)

    # Create clock connections for each block
    # Assign clocks into appropriate groups
    # Note, elaborate_instances references clock information to establish async handling
    # as part of alerts.
    # amend_clocks(topcfg)

    # Combine the wakeups
    amend_wkup(topcfg, name_to_block)
    amend_reset_request(topcfg, name_to_block)

    # Combine the interrupt (should be processed prior to xbar)
    amend_interrupt(topcfg, name_to_block)

    # Combine the alert (should be processed prior to xbar)
    amend_alert(topcfg, name_to_block)

    if lib.find_module(topcfg['module'], 'pinmux'):
        # Creates input/output list in the pinmux
        log.info("Processing PINMUX")
        amend_pinmux_io(topcfg, name_to_block)

    # Combine xbar into topcfg
    for xbar in xbarobjs.values():
        amend_xbar(topcfg, name_to_block, xbar)

    # 2nd phase of xbar (gathering the devices address range)
    for xbar in topcfg["xbar"]:
        xbar_cross(xbar, topcfg["xbar"])

    # Add path names to declared resets.
    # Declare structure for exported resets.
    amend_resets(topcfg, name_to_block)

    # Parse racl configuration and annotate individual modules affected.
    amend_racl(topcfg, name_to_block)

    # remove unwanted fields 'debug_mem_base_addr'
    topcfg.pop('debug_mem_base_addr', None)

    return topcfg
