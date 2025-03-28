# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Design constrains for Earlgrey ASIC

# Set default value for variables that are not predefined.
if {! [info exists synopsys_program_name]} {
    set synopsys_program_name ""
}
if {! [info exists spec_constr]} {
    set spec_constr 1
}

# Note that we do not fix hold timing in this flow
if { $synopsys_program_name eq "pt_shell" } {
set SETUP_CLOCK_UNCERTAINTY 0.05
} else {
set SETUP_CLOCK_UNCERTAINTY 0.5
}
set CLK_PERIOD_FACTOR $CLK_PERIOD_FACTOR ;# clock period over constraining factor
puts "Applying constraints for top level"

# Note: the netlist does include pads at this level, but not all IO interfaces
# have been constrained. The clocks are generated inside AST and
# for the purpose of test synthesis, these clock nets are just set to ideal networks.

#####################
# Architectural CGs #
#####################

# This is not needed by CDC runs
if {!$IS_CDC_RUN} {
    # in synthesis, we treat all clock networks as ideal nets.
    # architecturally insterted CGs however can be interpreted as
    # sequential cells by the tool, hence stopping automatic propagation
    # of ideal network attributes. therefore, we go through the design and
    # declare all architectural CG outputs as ideal.
    set_ideal_network [get_pins -hier u_clkgate/Q]
}

#####################
# main clock        #
#####################
set MAIN_CLK_PIN $MAIN_CLK_PIN
set MAIN_RST_PIN IO_RST_N
# target is 100MHz, overconstrain by factor
set MAIN_TCK_TARGET_PERIOD  10
set MAIN_TCK_FACTOR $MAIN_TCK_FACTOR
set MAIN_TCK_PERIOD [expr $MAIN_TCK_TARGET_PERIOD*$MAIN_TCK_FACTOR] ;# over constraining
# For now we remove this as clock is, by default, ideal. Reset, we'll try w/o ideal_network.
#set_ideal_network [get_pins ${MAIN_CLK_PIN}]
#set_ideal_network [get_ports ${MAIN_RST_PIN}]

create_clock -name MAIN_CLK -period ${MAIN_TCK_PERIOD} [get_pins ${MAIN_CLK_PIN}] -add
set_clock_uncertainty ${SETUP_CLOCK_UNCERTAINTY} [get_clocks MAIN_CLK]
#set_false_path -from [get_clocks ${MAIN_CLK_PIN_AST}] -to [get_clocks ${MAIN_CLK_PIN}]
#####################
# USB clock         #
#####################
set USB_CLK_PIN $USB_CLK_PIN
# target is 48MHz, overconstrain by 5%
set USB_TCK_TARGET_PERIOD 20.8
set USB_TCK_PERIOD [expr $USB_TCK_TARGET_PERIOD*$CLK_PERIOD_FACTOR]
# USB clock uncertainty needs to be within 2500ppm
set USB_CLOCK_UNCERTAINTY [expr $USB_TCK_PERIOD * .0025]
create_clock -name USB_CLK -period ${USB_TCK_PERIOD} [get_pins ${USB_CLK_PIN}] -add
set_clock_uncertainty ${USB_CLOCK_UNCERTAINTY} [get_clocks USB_CLK]

# This requires knowledge of actual pin names, hence we only run this if we're compiling against
# real libs (i.e., not GTECH mode).
if {$FOUNDRY_ROOT != ""} {
  # generic constraints to make sure all reg <-> pad paths have a constraint.
  # specific constraints to minimize skew are further below.
  set FLOP_PATH gen_*u_impl*/gen_flops?0?*?u_size_only_reg
  set_max_delay 5 -from [get_pins top_earlgrey/u_usbdev/usbdev_impl/u_usb_fs_nb_pe/u_usb_fs_tx/u_*_flop/${FLOP_PATH}/Q] \
                  -to   [get_ports USB_*]
  set_max_delay 5 -from [get_ports USB_*] \
                  -to   [get_pins top_earlgrey/u_usbdev/i_usbdev_iomux/cdc_io_to_usb/gen_generic_u_impl_generic/u_sync_1/${FLOP_PATH}/D]

  # The USB 2.0 spec specifies that full-speed driver rise/fall times can be 4ns to 20ns, and that
  # differential edges should be within +-10% to minimize skew. Assuming the fastest rise/fall time
  # of 4ns, we end up with a maximum skew tolerance of 400ps. In order to make the constraints
  # straightforward, we use set_max_delay between output flop and pad driver, and constrain to 350ps to
  # retain some margin.
  set MAX_USB_DELAY 0.35

  # output enable timing
  set_max_delay ${MAX_USB_DELAY} -from [get_pins top_earlgrey/u_usbdev/usbdev_impl/u_usb_fs_nb_pe/u_usb_fs_tx/u_oe_flop/${FLOP_PATH}/Q*] \
                                 -to  [get_pins -hierarchical -filter "full_name =~ *u_dio_pad*usb_pad_wrap/u_pad_macro_PBIDIR_*/OE"]
  # dp output timing
  # note that there is a path to the OE as well due to virtual open drain emulation in the pad wrapper (although it is likely not being used for USB).
  set_max_delay ${MAX_USB_DELAY} -from [get_pins top_earlgrey/u_usbdev/usbdev_impl/u_usb_fs_nb_pe/u_usb_fs_tx/u_usb_dp_o_flop/${FLOP_PATH}/Q*] \
                                 -to   [get_pins -hierarchical -filter "full_name =~ *u_dio_pad*usb_pad_wrap/u_pad_macro_PBIDIR_*/OE"]
  set_max_delay ${MAX_USB_DELAY} -from [get_pins top_earlgrey/u_usbdev/usbdev_impl/u_usb_fs_nb_pe/u_usb_fs_tx/u_usb_dp_o_flop/${FLOP_PATH}/Q*] \
                                 -to  [get_pins -hierarchical -filter "full_name =~ *u_dio_pad*usb_pad_wrap/u_pad_macro_PBIDIR_*/A"]

  # dn output timing
  # note that there is a path to the OE as well due to virtual open drain emulation in the pad wrapper (although it is likely not being used for USB).
  set_max_delay ${MAX_USB_DELAY} -from [get_pins top_earlgrey/u_usbdev/usbdev_impl/u_usb_fs_nb_pe/u_usb_fs_tx/u_usb_dn_o_flop/${FLOP_PATH}/Q*] \
                                 -to   [get_pins -hierarchical -filter "full_name =~ *u_dio_pad*usb_pad_wrap/u_pad_macro_PBIDIR_*/OE"]
  set_max_delay ${MAX_USB_DELAY} -from [get_pins top_earlgrey/u_usbdev/usbdev_impl/u_usb_fs_nb_pe/u_usb_fs_tx/u_usb_dn_o_flop/${FLOP_PATH}/Q*] \
                                 -to  [get_pins -hierarchical -filter "full_name =~ *u_dio_pad*usb_pad_wrap/u_pad_macro_PBIDIR_*/A"]


  # We reuse the same set_max_delay constraints as for the driver paths to stay on the safe side
  # (there is more skew budget on the receiver side according to the spec, but we shouldn't be using that
  # up since there would otherwise be no margin for cable and PCB skew).
  #
  # The USBDEV has both a regular and a differential amplifier input mode.
  # For the former, the skew only matters up to the differential amplifier inputs.
  # For the latter, we need to constrain the skew up to the flop inputs.

  # dp input timing to differential receiver
  set_max_delay ${MAX_USB_DELAY} -from [get_ports USB_P]                                        \
                                 -to [get_pins -leaf -filter {@pin_direction == in} -of_objects \
                                        [get_nets -segments -of_objects                         \
                                          [get_pins u_prim_usb_diff_rx/input_pi]]]

  # dn input timing to differential receiver
  set_max_delay ${MAX_USB_DELAY} -from [get_ports USB_N]                                        \
                                 -to [get_pins -leaf -filter {@pin_direction == in} -of_objects \
                                        [get_nets -segments -of_objects                         \
                                          [get_pins u_prim_usb_diff_rx/input_ni]]]

  # dp/dn input timing to regular regs
  set_max_delay ${MAX_USB_DELAY} -from [get_pins -hierarchical -filter "full_name =~ *u_dio_pad*usb_pad_wrap/u_pad_macro_PBIDIR_*/Y"] \
                                 -to   [get_pins top_earlgrey/u_usbdev/i_usbdev_iomux/cdc_io_to_usb/gen_generic_u_impl_generic/u_sync_1/${FLOP_PATH}/D]
}

#####################
# IO clk            #
#####################
set IO_CLK_PIN $IO_CLK_PIN
# target is 96MHz, overconstrain by factor
set IO_TCK_TARGET_PERIOD 10.416
set IO_TCK_PERIOD [expr $IO_TCK_TARGET_PERIOD*$CLK_PERIOD_FACTOR]

create_clock -name IO_CLK -period ${IO_TCK_PERIOD} [get_pins ${IO_CLK_PIN}] -add
set_clock_uncertainty ${SETUP_CLOCK_UNCERTAINTY} [get_clocks IO_CLK]

# This requires knowledge of actual port name
set CLK_DST_NAME $CLK_DST_PIN

# generated clocks (div2/div4)
set CLK_PATH top_earlgrey/u_clkmgr_aon/u_no_scan_io_div2_div
create_generated_clock -name IO_DIV2_CLK  \
    -source [get_pins ${IO_CLK_PIN}] -divide_by 2 [get_pins ${CLK_PATH}/${CLK_DST_NAME}] -master IO_CLK -add

set CLK_PATH top_earlgrey/u_clkmgr_aon/u_no_scan_io_div4_div
create_generated_clock -name IO_DIV4_CLK  \
    -source [get_pins ${IO_CLK_PIN}] -divide_by 4 [get_pins ${CLK_PATH}/${CLK_DST_NAME}] -master IO_CLK -add

# Define these variables for later use
set IO_DIV2_TCK_PERIOD [expr $IO_TCK_PERIOD * 2]
set IO_DIV4_TCK_PERIOD [expr $IO_TCK_PERIOD * 4]

# note that due to the muxing, additional timing views with set_case_analysis may be needed.

# aggregate all IO banks
set IO_BANKS [get_ports IOA*]
append_to_collection IO_BANKS [get_ports IOB*]
append_to_collection IO_BANKS [get_ports IOC*]
append_to_collection IO_BANKS [get_ports IOR*]

# constrain muxed IOs running on IO_DIV2_CLK and IO_DIV4_CLK
set IO_IN_DEL_FRACTION 0.40
set IO_OUT_DEL_FRACTION 0.40

# IO_DIV2_CLK
set IO_DIV2_IN_DEL    [expr ${IO_IN_DEL_FRACTION} * ${IO_TCK_PERIOD} * 2.0]
set IO_DIV2_OUT_DEL   [expr ${IO_OUT_DEL_FRACTION} * ${IO_TCK_PERIOD} * 2.0]

set_input_delay ${IO_DIV2_IN_DEL}   ${IO_BANKS} -clock IO_DIV2_CLK -add_delay
set_output_delay ${IO_DIV2_OUT_DEL} ${IO_BANKS} -clock IO_DIV2_CLK -add_delay

# IO_DIV4_CLK
set IO_DIV4_IN_DEL    [expr ${IO_IN_DEL_FRACTION} * ${IO_TCK_PERIOD} * 4.0]
set IO_DIV4_OUT_DEL   [expr ${IO_OUT_DEL_FRACTION} * ${IO_TCK_PERIOD} * 4.0]

set_input_delay ${IO_DIV4_IN_DEL}   ${IO_BANKS} -clock IO_DIV4_CLK -add_delay
set_output_delay ${IO_DIV4_OUT_DEL} ${IO_BANKS} -clock IO_DIV4_CLK -add_delay

#####################
# sysrst_ctrl       #
#####################

# MIO paths that go into sysrst_ctrl and fan out into MIOs or dedicated sysrst_ctrl outputs are async in nature, hence we constrain them using a max delay.
set SYSRST_MAXDELAY 70.0
set_max_delay -from ${IO_BANKS} -to ${IO_BANKS} -through [get_cells top_earlgrey/u_sysrst_ctrl_aon/*] ${SYSRST_MAXDELAY}

#####################
# AON clk           #
#####################
set AON_CLK_PIN $AON_CLK_PIN
# target is 200KHz, overconstrain by factor
set AON_TCK_TARGET_PERIOD 5000.0
set AON_TCK_PERIOD [expr $AON_TCK_TARGET_PERIOD*$CLK_PERIOD_FACTOR]
#set_ideal_network [get_pins ${AON_CLK_PIN}]

create_clock -name AON_CLK -period ${AON_TCK_PERIOD} [get_pins ${AON_CLK_PIN}] -add
set_clock_uncertainty ${SETUP_CLOCK_UNCERTAINTY} [get_clocks AON_CLK]

#####################
# JTAG clock        #
#####################
set JTAG_CLK_PIN IOR3
# target is 30MHz, overconstrain by factor
set JTAG_TCK_TARGET_PERIOD 33.3
set JTAG_TCK_PERIOD [expr $JTAG_TCK_TARGET_PERIOD*$CLK_PERIOD_FACTOR]

create_clock -name JTAG_TCK -period $JTAG_TCK_PERIOD [get_ports $JTAG_CLK_PIN] -add
#set_ideal_network [get_ports $JTAG_CLK_PIN]
set_clock_uncertainty ${SETUP_CLOCK_UNCERTAINTY} [get_clocks JTAG_TCK]
set_propagated_clock JTAG_TCK

create_generated_clock -name LC_JTAG_TCK -source [get_ports IOR3] -divide_by 1 \
    [get_pins top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/u_pinmux_jtag_buf_lc/prim_clock_buf_tck/clk_o] -master_clock JTAG_TCK -add
create_generated_clock -name RV_JTAG_TCK -source [get_ports IOR3] -divide_by 1 \
    [get_pins top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/u_pinmux_jtag_buf_rv/prim_clock_buf_tck/clk_o] -master_clock JTAG_TCK -add

set LC_JTAG_TCK_INV_PIN \
  [get_pins -leaf -filter {@pin_direction == out} -of_objects \
    [get_nets -segments -of_objects \
      [get_pins top_earlgrey/u_lc_ctrl/u_dmi_jtag/i_dmi_jtag_tap/i_tck_inv/clk_no] \
    ] \
  ]

set RV_JTAG_TCK_INV_PIN \
  [get_pins -leaf -filter {@pin_direction == out} -of_objects \
    [get_nets -segments -of_objects \
      [get_pins top_earlgrey/u_rv_dm/dap/i_dmi_jtag_tap/i_tck_inv/clk_no] \
    ] \
  ]

set_clock_sense -negative ${LC_JTAG_TCK_INV_PIN}
set_clock_sense -negative ${RV_JTAG_TCK_INV_PIN}

set_output_delay -add_delay             -clock JTAG_TCK -max  7.0 [get_ports IOR1]
set_output_delay -add_delay             -clock JTAG_TCK -min -5.0 [get_ports IOR1]
set_input_delay  -add_delay -clock_fall -clock JTAG_TCK -min  0.0 [get_ports {IOR0 IOR2}]
set_input_delay  -add_delay -clock_fall -clock JTAG_TCK -max  8.0 [get_ports {IOR0 IOR2}]

# Don't apply these constraints to the DFT TAP. Leave this to the
# implementation.
if { $synopsys_program_name eq "pt_shell" || $synopsys_program_name eq "icc2_shell" || $synopsys_program_name eq "dc_shell"  } {
set_clock_sense -stop_propagation -clock JTAG_TCK \
  [get_pins -leaf -filter "@pin_direction == out" -of_objects \
    [get_nets -segments -of_objects \
      [get_pins top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/u_pinmux_jtag_buf_dft/prim_clock_buf_tck/clk_o] \
    ] \
  ]
} else {
set_clock_sense -logical_stop_propagation -clock JTAG_TCK \
  [get_pins -leaf -filter "@pin_direction == out" -of_objects \
    [get_nets -segments -of_objects \
      [get_pins top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/u_pinmux_jtag_buf_dft/prim_clock_buf_tck/clk_o] \
    ] \
  ]
}
# Don't carry the JTAG clock through the pinmux.
set_clock_sense -stop_propagation -clock JTAG_TCK \
  [get_pins -leaf -filter "@pin_direction == out" -of_objects \
    [get_nets -segments -of_objects \
      [get_pins top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/in_core_o[38]] \
    ] \
  ]
set_false_path -hold -from [get_clocks JTAG_TCK] \
  -to [get_ports IOR1] \
  -through [get_ports "IOR0 IOR2 IOR3"]  \
  -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
    [get_nets -segments -of_objects \
      [get_pins top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/in_core_o*] \
    ] \
  ]

#####################
# AST clock        #
#####################

set AST_EXT_CLK_PIN IOC6
# target is 48MHz, overconstrain by factor
set AST_EXT_TCK_TARGET_PERIOD [expr $IO_TCK_TARGET_PERIOD*2]
set AST_EXT_TCK_PERIOD [expr $AST_EXT_TCK_TARGET_PERIOD*$CLK_PERIOD_FACTOR]

create_clock -name AST_EXT_CLK -period ${AST_EXT_TCK_PERIOD} [get_ports ${AST_EXT_CLK_PIN}] -add
set_clock_uncertainty -setup  ${SETUP_CLOCK_UNCERTAINTY} [get_clocks AST_EXT_CLK]

# This is not needed by CDC runs because io_clk/usb_clk/main_clk/aon_clk are propagated from ast_ext_clk in ast.lib
# we don't use this constraint to avoid unnecessary CDC issues
if {!$IS_CDC_RUN} {
    set_clock_groups -name group_ast -async -group [get_clocks AST_EXT_CLK]
}
####################################
# SPI System Parameters             #
#####################################

# Routing delay from external component to device
# Represents approximately 5 inches of trace
set PCB_DEL 0.85

# Max skew between signals. Represents approximately 3 inches.
set PCB_SKEW 0.51

# external spi host setup and hold
set HOST_SETUP_DEL 5
set HOST_HOLD_DEL -5
# Limit hold requirements for full-cycle sampling.
set HOST_HOLD_DEL_FULL_CYCLE -2

# external spi host clk-to-q
set HOST_OUT_DEL_MIN -2
set HOST_OUT_DEL_MAX  3

# external spi dev setup and hold
set STORAGE_SETUP_DEL 3
set STORAGE_HOLD_DEL -3

# external spi dev clk-to-q
set STORAGE_OUT_DEL_MIN 0
set STORAGE_OUT_DEL_MAX 9

###################################################
# SPI input outpt delay based Ziv Spec
###################################################
# Note: below values apply if the spec_constr variable is set to "false".
# If the spec_constr variable is set to true:
# - below values are not used, and
# - the values defined in other sections of this SDC are used instead (see e.g. "SPI_HOST_1 timing (full-cycle sampling)").
#
# For Earlgrey-PROD, both sets of constraints (spec_constr "true" and "false") have been verified.
# In the future, those can ideally be merged together.

if { $synopsys_program_name eq "pt_shell" } {
set out_val 0
} else {
set out_val 3
}

set spi_host_inp_max             11.5
set spi_host_inp_min               -1
set spi_host_out_val_max          [expr 5.5 + $out_val]
set spi_host_out_val_min          -9

set spi_host1_inp_max                8
set spi_host1_inp_min                0
set spi_host1_out_val_max          [expr 4.5 + $out_val]
set spi_host1_out_val_min          -0.5

set spi_dev_inp_max                 5
set spi_dev_inp_min                -7
set spi_dev_inp_csb_max             5
set spi_dev_inp_csb_min            -3
set spi_dev_out_val_max           [expr 7.5 + $out_val]
set spi_dev_out_val_min            -2

set spi_tpm_inp_max                18
set spi_tpm_inp_min               -17
set spi_tpm_inp_csb_max            15
set spi_tpm_inp_csb_min           -17
set spi_tpm_out_val_max           [expr 7.5 + $out_val]
set spi_tpm_out_val_min           -22

set spi_dev_hc_inp_max             15
set spi_dev_hc_inp_min            -17
set spi_dev_hc_inp_csb_max         15
set spi_dev_hc_inp_csb_min        -17
set spi_dev_hc_out_val_max        [expr 7.5 + $out_val]
set spi_dev_hc_out_val_min        -22

set spi_fast_pass_host_inp_max     16
set spi_fast_pass_host_inp_min      0

set spi_fast_pass_dev_out_val_max   [expr 12.5 + $out_val]
set spi_fast_pass_dev_out_val_min   -2

set spi_fast_pass_soc_in_max        4.8
set spi_fast_pass_soc_in_min       -5
set spi_fast_pass_flsh_out_max     [expr  5 + $out_val]
set spi_fast_pass_flsh_out_min     -4.8

set spi_slow_pass_flsh_in_max    10.7
set spi_slow_pass_flsh_in_min       0
set spi_slow_pass_soc_out_max      [expr 6.7 + $out_val]
set spi_slow_pass_soc_out_min      -2

#################
# SPI DEV clock #
#################
# TODO
# Add source delays for generated clocks

# The SPI DEV section is for all non-passthrough modes with full-cycle sampling.
# The full-cycle sampling target frequency is 48 MHz.
set SPI_DEV_CLK_PIN SPI_DEV_CLK
# Target is 48 MHz. Overconstrain to 50 MHz.
set SPI_DEV_TCK 20.0
set SPI_DEV_TCK_HALF [expr ${SPI_DEV_TCK} / 2]
#set_ideal_network ${SPI_DEV_CLK_PIN}

# Board skew affects input sampling path.
set SPI_DEV_IN_DEL_MIN [expr ${HOST_OUT_DEL_MIN} - ${PCB_SKEW}]
set SPI_DEV_IN_DEL_MAX [expr ${HOST_OUT_DEL_MAX} + ${PCB_SKEW}]

# Board propagation delay affects return path.
set SPI_DEV_OUT_DEL_MIN ${HOST_HOLD_DEL}
set SPI_DEV_OUT_DEL_MIN_FC ${HOST_HOLD_DEL_FULL_CYCLE}
set SPI_DEV_OUT_DEL_MAX [expr ${HOST_SETUP_DEL} + 2 * ${PCB_DEL}]

create_clock -name SPI_DEV_CLK  -period ${SPI_DEV_TCK} [get_ports ${SPI_DEV_CLK_PIN}] -add
set_clock_uncertainty ${SETUP_CLOCK_UNCERTAINTY} [get_clocks SPI_DEV_CLK]
set_propagated_clock SPI_DEV_CLK

create_generated_clock -name SPI_DEV_IN_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_in_buf/${CLK_PIN}] -master_clock SPI_DEV_CLK -add
create_generated_clock -name SPI_DEV_OUT_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 -invert \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_out_buf/${CLK_PIN}] -master_clock SPI_DEV_CLK -add

# bidir ports
set SPI_DEV_DATA_PORTS [get_ports {SPI_DEV_D0 SPI_DEV_D1 SPI_DEV_D2 SPI_DEV_D3}]
if {$spec_constr} {
set_input_delay -min ${SPI_DEV_IN_DEL_MIN} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_CLK -add_delay
set_input_delay -max ${SPI_DEV_IN_DEL_MAX} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_CLK -add_delay
} else {
set_input_delay -min $spi_dev_inp_min ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_CLK -add_delay
set_input_delay -max $spi_dev_inp_max ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_CLK -add_delay
}
# Full-cycle sampling has the host on the next falling edge.
if {$spec_constr} {
set_output_delay -min ${SPI_DEV_OUT_DEL_MIN_FC} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_CLK -add_delay
set_output_delay -max ${SPI_DEV_OUT_DEL_MAX} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_CLK -add_delay
} else {
set_output_delay -min $spi_dev_out_val_min ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_CLK -add_delay
set_output_delay -max $spi_dev_out_val_max ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_CLK -add_delay
}
set_multicycle_path -setup 2 -from [get_clocks SPI_DEV_IN_CLK] \
    -to [get_clocks SPI_DEV_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}]
#leonids updated based on interaction with Alex
set_multicycle_path -hold -end 1 -from [get_clocks SPI_DEV_IN_CLK] \
    -to [get_clocks SPI_DEV_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}]

# SPI DEV CSB, the chip-select for non-TPM modes, acts as clock, data, and
# reset.
create_clock -name SPI_DEV_CSB_CLK -period [expr 2 * ${SPI_DEV_TCK}] \
    -waveform "${SPI_DEV_TCK_HALF} [expr ${SPI_DEV_TCK_HALF} + ${SPI_DEV_TCK}]" \
    [get_ports SPI_DEV_CS_L] -add
if {$spec_constr} {
set_clock_latency -source -min ${SPI_DEV_IN_DEL_MIN} [get_clocks SPI_DEV_CSB_CLK]
set_clock_latency -source -max ${SPI_DEV_IN_DEL_MAX} [get_clocks SPI_DEV_CSB_CLK]
} else {
set_clock_latency -source -min $spi_dev_inp_csb_min [get_clocks SPI_DEV_CSB_CLK]
set_clock_latency -source -max $spi_dev_inp_csb_max [get_clocks SPI_DEV_CSB_CLK]
}
set_propagated_clock [get_clocks SPI_DEV_CSB_CLK]
if { $synopsys_program_name eq "pt_shell" || $synopsys_program_name eq "icc2_shell" || $synopsys_program_name eq "dc_shell"  } {
set_clock_sense -stop_propagation [get_pins -leaf -of_objects top_earlgrey/u_spi_device/u_csb_buf/out_o[0]]
} else {
set_clock_sense -logical_stop_propagation [get_pins -leaf -of_objects [get_pins top_earlgrey/u_spi_device/u_csb_buf/out_o[0]]]
}
# CSB-clocked status bits to various negedge-triggered flops, especially in the
# serializer.
# Advance the hold edge by one cycle, since CSB changes nominally on the same
# edge as SPI_DEV_OUT_CLK, but SPI_DEV_OUT_CLK isn't actually toggling.
#set_ideal_network [get_pins top_earlgrey/u_spi_device/u_csb_rst_scan_mux/clk_o]
set_multicycle_path -hold -end -from [get_clocks SPI_DEV_CSB_CLK] \
    -to [get_clocks SPI_DEV_OUT_CLK] 1
# Because this section does full-cycle sampling, the same moving of the capture
# edge is needed for SPI_DEV_CSB_CLK -> SPI_DEV_D* hold analysis. The default
# falling edge of SPI_DEV_CLK would not be active.
set_multicycle_path -hold -end -from [get_clocks SPI_DEV_CSB_CLK] \
    -to [get_clocks SPI_DEV_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}] 1
# Relax the hold time constraint for the passthrough clock gate. Really this is
# to accommodate the gate for the inverted clock, which isn't active for the
# modes used for these constraints. However, it would be an okay outcome if the
# filter result reached the gate before even the 7th clock edge got out.
set_multicycle_path -hold -end 1 -from [get_clocks SPI_DEV_CLK] \
    -to [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets top_earlgrey/u_spi_device/u_passthrough/sck_gate_en]]

##
# Remove hold analysis from the following paths to ports. Even though the pins
# can change before the prior data was latched upstream, their effect is held
# back by other logic on SPI_DEV_OUT_CLK.
# Note: The final output logic equation must not permit glitches in the presence
# of changes on the listed pins. Otherwise, any hold time failures could be
# real.
##

# This path is from locality logic that is on the *_IN_CLK domain and selects
# between fixed values or the return-by-hw register value. The flopped bits
# settle in the middle of the command/address phase, many cycles before the
# data phase.
set_false_path -hold -from [get_clocks SPI_DEV_IN_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_spi_tpm/miso_o]]]

# Remove scan paths for timing analysis
set_clock_sense -stop_propagation -clock SPI_DEV_CLK [get_pins -leaf -filter "@pin_direction == in" -of_objects [get_nets -segments -of_objects [get_pins u_ast/u_scan_clk/in_i*]]]
set_false_path -from [get_clocks SPI_DEV_CSB_CLK] \
    -through [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets -segments -of_objects \
            [get_pins u_ast/u_scan_rst_n/in_i*]]]


############################
# SPI DEV HALF CYCLE clock #
############################
# The SPI DEV HALF CYCLE section is for all non-passthrough modes with
# half-cycle sampling.
# The half-cycle sampling target frequency is 24 MHz.
set SPI_DEV_CLK_PIN SPI_DEV_CLK
# Target is 24 MHz. Overconstrain to 25 MHz.
set SPI_DEV_HC_TCK 40.0
set SPI_DEV_HC_TCK_HALF [expr ${SPI_DEV_HC_TCK} / 2]

create_clock -name SPI_DEV_HC_CLK -period ${SPI_DEV_HC_TCK} [get_ports ${SPI_DEV_CLK_PIN}] -add
set_clock_uncertainty ${SETUP_CLOCK_UNCERTAINTY} [get_clocks SPI_DEV_HC_CLK]
set_propagated_clock SPI_DEV_HC_CLK

create_generated_clock -name SPI_DEV_HC_IN_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_in_buf/${CLK_PIN}] -add -master_clock SPI_DEV_HC_CLK
create_generated_clock -name SPI_DEV_HC_OUT_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 -invert \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_out_buf/${CLK_PIN}] -add -master_clock SPI_DEV_HC_CLK

# bidir ports
set SPI_DEV_DATA_PORTS [get_ports {SPI_DEV_D0 SPI_DEV_D1 SPI_DEV_D2 SPI_DEV_D3}]
if {$spec_constr} {
set_input_delay -min ${SPI_DEV_IN_DEL_MIN} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_HC_CLK -add_delay
set_input_delay -max ${SPI_DEV_IN_DEL_MAX} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_HC_CLK -add_delay
} else {
set_input_delay -min $spi_dev_hc_inp_min ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_HC_CLK -add_delay
set_input_delay -max $spi_dev_hc_inp_max ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_HC_CLK -add_delay
}
# Half-cycle sampling has the host on the next rising edge.
if {$spec_constr} {
set_output_delay -min ${SPI_DEV_OUT_DEL_MIN} ${SPI_DEV_DATA_PORTS} \
    -clock SPI_DEV_HC_CLK -add_delay
set_output_delay -max ${SPI_DEV_OUT_DEL_MAX} ${SPI_DEV_DATA_PORTS} \
    -clock SPI_DEV_HC_CLK -add_delay
} else {
set_output_delay -min $spi_dev_hc_out_val_min ${SPI_DEV_DATA_PORTS} \
    -clock SPI_DEV_HC_CLK -add_delay
set_output_delay -max $spi_dev_hc_out_val_max ${SPI_DEV_DATA_PORTS} \
    -clock SPI_DEV_HC_CLK -add_delay
}
# SPI DEV CSB, the chip-select for non-TPM modes, acts as clock, data, and
# reset.
create_clock -name SPI_DEV_HC_CSB_CLK -period [expr 2 * ${SPI_DEV_HC_TCK}] \
    -waveform "${SPI_DEV_HC_TCK_HALF} [expr ${SPI_DEV_HC_TCK_HALF} + ${SPI_DEV_HC_TCK}]" \
    [get_ports SPI_DEV_CS_L] -add
if {$spec_constr} {
set_clock_latency -source -min ${SPI_DEV_IN_DEL_MIN} [get_clocks SPI_DEV_HC_CSB_CLK]
set_clock_latency -source -max ${SPI_DEV_IN_DEL_MAX} [get_clocks SPI_DEV_HC_CSB_CLK]
} else {
set_clock_latency -source -min $spi_dev_hc_inp_csb_min [get_clocks SPI_DEV_HC_CSB_CLK]
set_clock_latency -source -max $spi_dev_hc_inp_csb_max [get_clocks SPI_DEV_HC_CSB_CLK]
}
set_propagated_clock [get_clocks SPI_DEV_HC_CSB_CLK]
if { $synopsys_program_name eq "pt_shell" || $synopsys_program_name eq "icc2_shell" || $synopsys_program_name eq "dc_shell"  } {
set_clock_sense -stop_propagation [get_pins -leaf -of_objects top_earlgrey/u_spi_device/u_csb_buf/out_o[0]]
} else {
set_clock_sense -logical_stop_propagation [get_pins -leaf -of_objects top_earlgrey/u_spi_device/u_csb_buf/out_o[0]]
}
# CSB-clocked status bits to various negedge-triggered flops, especially in the
# serializer.
# Advance the hold edge by one cycle, since CSB changes nominally on the same
# edge as SPI_DEV_OUT_CLK, but SPI_DEV_OUT_CLK isn't actually toggling.
#set_ideal_network [get_pins top_earlgrey/u_spi_device/u_csb_rst_scan_mux/clk_o]
set_multicycle_path -hold -end -from [get_clocks SPI_DEV_HC_CSB_CLK] \
    -to [get_clocks SPI_DEV_HC_OUT_CLK] 1
# Because this section does full-cycle sampling, the same moving of the capture
# edge is needed for SPI_DEV_CSB_CLK -> SPI_DEV_D* hold analysis. The default
# falling edge of SPI_DEV_CLK would not be active.
set_multicycle_path -hold -end -from [get_clocks SPI_DEV_HC_CSB_CLK] \
    -to [get_clocks SPI_DEV_HC_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}] 1
# Relax the hold time constraint for the passthrough clock gate. Really this is
# to accommodate the gate for the inverted clock, which isn't active for the
# modes used for these constraints. However, it would be an okay outcome if the
# filter result reached the gate before even the 7th clock edge got out.
set_multicycle_path -hold -end 1 -from [get_clocks SPI_DEV_HC_CLK] \
    -to [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets top_earlgrey/u_spi_device/u_passthrough/sck_gate_en]]

##
# Remove hold analysis from the following paths to ports. Even though the pins
# can change before the prior data was latched upstream, their effect is held
# back by other logic on SPI_DEV_HC_OUT_CLK.
# Note: The final output logic equation must not permit glitches in the presence
# of changes on the listed pins. Otherwise, any hold time failures could be
# real.
##

# This path is from locality logic that is on the *_IN_CLK domain and selects
# between fixed values or the return-by-hw register value. The flopped bits
# settle in the middle of the command/address phase, many cycles before the
# data phase.
set_false_path -hold -from [get_clocks SPI_DEV_HC_IN_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_spi_tpm/miso_o]]]

# Remove scan paths for timing analysis
set_clock_sense -stop_propagation -clock SPI_DEV_HC_CLK [get_pins -leaf -filter "@pin_direction == in" -of_objects [get_nets -segments -of_objects [get_pins u_ast/u_scan_clk/in_i*]]]
set_false_path -from [get_clocks SPI_DEV_HC_CSB_CLK] \
    -through [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets -segments -of_objects \
            [get_pins u_ast/u_scan_rst_n/in_i*]]]

# false path from spi_cmdparse to the ports on SPI_DEV_HC_CLK
set_false_path -hold -from [get_clocks SPI_DEV_HC_IN_CLK] \
    -to [get_clocks SPI_DEV_HC_CLK] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
        [get_cells -filter "@is_sequential" top_earlgrey/u_spi_device/u_cmdparse/*]]

set_false_path -hold -from [get_clocks SPI_DEV_HC_IN_CLK] \
    -to [get_clocks SPI_DEV_HC_CLK] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
        [get_cells -filter "@is_sequential" top_earlgrey/u_spi_device/u_passthrough/cmd_info_reg_read_pipeline_mode*]]

####################
# SPI DEV TPM mode #
####################
# The SPI DEV TPM section is for TPM mode with half-cycle sampling. The TPM mode
# has its own constraint section, since the setup and hold characteristics come
# from the TPM spec, and these may be substantially different from what are
# required for flash mode.
# The half-cycle sampling target frequency is 24 MHz. Over-constrain to 25 MHz.
set SPI_TPM_TCK 40.0
set SPI_TPM_TCK_HALF [expr ${SPI_TPM_TCK} / 2]
set SPI_TPM_CSB_HOLD 5.0
set SPI_TPM_CSB_SETUP 10.0
set SPI_TPM_MOSI_HOLD 5.0
set SPI_TPM_MOSI_SETUP 10.0
set SPI_TPM_MISO_CLKQ_MIN 0.0
set SPI_TPM_MISO_CLKQ_MAX 12.6
set SPI_TPM_CSB_IN_DEL_MIN [expr ${SPI_TPM_CSB_HOLD} - ${SPI_TPM_TCK_HALF}]
set SPI_TPM_CSB_IN_DEL_MAX [expr ${SPI_TPM_TCK_HALF} - ${SPI_TPM_CSB_SETUP}]
set SPI_TPM_MOSI_IN_DEL_MIN [expr ${SPI_TPM_MOSI_HOLD} - ${SPI_TPM_TCK_HALF}]
set SPI_TPM_MOSI_IN_DEL_MAX [expr ${SPI_TPM_TCK_HALF} - ${SPI_TPM_MOSI_SETUP}]
set SPI_TPM_MISO_OUT_DEL_MIN ${SPI_TPM_MISO_CLKQ_MIN}
set SPI_TPM_MISO_OUT_DEL_MAX [expr ${SPI_TPM_TCK_HALF} - ${SPI_TPM_MISO_CLKQ_MAX}]

create_clock -name SPI_TPM_CLK -add -period ${SPI_TPM_TCK} [get_ports ${SPI_DEV_CLK_PIN}] -add
set_clock_uncertainty ${SETUP_CLOCK_UNCERTAINTY} [get_clocks SPI_TPM_CLK]
set_propagated_clock SPI_TPM_CLK

create_generated_clock -name SPI_TPM_IN_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 \
    -master_clock SPI_TPM_CLK -add \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_in_buf/${CLK_PIN}]
create_generated_clock -name SPI_TPM_OUT_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 -invert \
    -master_clock SPI_TPM_CLK -add \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_out_buf/${CLK_PIN}]

# bidir ports
if {$spec_constr} {
set_input_delay -min ${SPI_TPM_MOSI_IN_DEL_MIN} [get_ports SPI_DEV_D0] \
    -clock_fall -clock SPI_TPM_CLK -add_delay
set_input_delay -max ${SPI_TPM_MOSI_IN_DEL_MAX} [get_ports SPI_DEV_D0] \
    -clock_fall -clock SPI_TPM_CLK -add_delay
} else {
set_input_delay -min $spi_tpm_inp_min [get_ports SPI_DEV_D0] \
    -clock_fall -clock SPI_TPM_CLK -add_delay
set_input_delay -max $spi_tpm_inp_max [get_ports SPI_DEV_D0] \
    -clock_fall -clock SPI_TPM_CLK -add_delay
}
# Half-cycle sampling has the host on the next rising edge.
if {$spec_constr} {
set_output_delay -min ${SPI_TPM_MISO_OUT_DEL_MIN} [get_ports SPI_DEV_D1] \
    -clock SPI_TPM_CLK -add_delay
set_output_delay -max ${SPI_TPM_MISO_OUT_DEL_MAX} [get_ports SPI_DEV_D1] \
    -clock SPI_TPM_CLK -add_delay
} else {
set_output_delay -min $spi_tpm_out_val_min [get_ports SPI_DEV_D1] \
    -clock SPI_TPM_CLK -add_delay
set_output_delay -max $spi_tpm_out_val_max [get_ports SPI_DEV_D1] \
    -clock SPI_TPM_CLK -add_delay
}
# SPI TPM CSB, the chip-select for TPM mode.
# Any muxed port could be a SPI TPM CSB, but:
# - IOA7 has been selected as the primary target and we guarantee it meets timing.
# - IOA2 was selected as a secondary opportunistic target.
set TPM_CSB_PORT [get_ports {IOA7 IOA2}]

# TPM CSB input delays.
if {$spec_constr} {
set_input_delay -min ${SPI_TPM_CSB_IN_DEL_MIN} [get_ports ${TPM_CSB_PORT}] \
    -clock SPI_TPM_CLK -clock_fall -add_delay
set_input_delay -max ${SPI_TPM_CSB_IN_DEL_MAX} [get_ports ${TPM_CSB_PORT}] \
    -clock SPI_TPM_CLK -clock_fall -add_delay
} else {
set_input_delay -min $spi_tpm_inp_csb_min [get_ports ${TPM_CSB_PORT}] \
    -clock SPI_TPM_CLK -clock_fall -add_delay
set_input_delay -max $spi_tpm_inp_csb_max [get_ports ${TPM_CSB_PORT}] \
    -clock SPI_TPM_CLK -clock_fall -add_delay
}
# Relax hold path for TPM CSB, since CSB changes nominally on the same edge as
# SPI_TPM_OUT_CLK, but the latter isn't actually toggling.
set_multicycle_path -hold -end 1 -from [get_ports ${TPM_CSB_PORT}] \
    -to [get_clocks SPI_TPM_OUT_CLK] \
    -through [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets -segments -of_objects \
            [get_pins top_earlgrey/u_spi_device/u_spi_tpm/rst_ni]]]
# Relax the hold time constraint for the passthrough clock gate. Really this is
# to accommodate the gate for the inverted clock, which isn't active for the
# modes used for these constraints. However, it would be an okay outcome if the
# filter result reached the gate before even the 7th clock edge got out.
set_multicycle_path -hold -end 1 -from [get_clocks SPI_TPM_CLK] \
    -to [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets top_earlgrey/u_spi_device/u_passthrough/sck_gate_en]]

# Remove paths originating from flash logic.
set_false_path -from [get_clocks SPI_TPM_IN_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_p2s/data_valid_i]]]
set_false_path -from [get_clocks SPI_TPM_IN_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_p2s/data_i*]]]
set_false_path -from [get_clocks SPI_TPM_OUT_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_p2s/s_o*]]]
set_false_path -from [get_clocks SPI_TPM_OUT_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_p2s/s_en_o*]]]
set_false_path -from [get_clocks SPI_TPM_OUT_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_read_pipe_stg1/q_o*]]]
set_false_path -from [get_clocks SPI_TPM_OUT_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_read_en_pipe_stg1/q_o*]]]
set_false_path -from [get_clocks SPI_TPM_OUT_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_read_pipe_stg2/q_o*]]]
set_false_path -from [get_clocks SPI_TPM_OUT_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_read_en_pipe_stg2/q_o*]]]

##
# Remove hold analysis from the following paths to ports. Even though the pins
# can change before the prior data was latched upstream, their effect is held
# back by other logic on SPI_TPM_OUT_CLK.
# Note: The final output logic equation must not permit glitches in the presence
# of changes on the listed pins. Otherwise, any hold time failures could be
# real.
##

# This path is from locality logic that is on the *_IN_CLK domain and selects
# between fixed values or the return-by-hw register value. The flopped bits
# settle in the middle of the command/address phase, many cycles before the
# data phase.
set_false_path -hold -from [get_clocks SPI_TPM_IN_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_spi_tpm/miso_o]]]

# Remove scan paths for timing analysis
set_clock_sense -stop_propagation -clock SPI_TPM_CLK [get_pins -leaf -filter "@pin_direction == in" -of_objects [get_nets -segments -of_objects [get_pins u_ast/u_scan_clk/in_i*]]]

set_false_path -hold -from [get_clocks SPI_TPM_IN_CLK] \
    -to [get_clocks SPI_TPM_CLK] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
        [get_cells -filter "@is_sequential" top_earlgrey/u_spi_device/u_cmdparse/*]]

set_false_path -hold -from [get_clocks SPI_TPM_CLK] \
    -to [get_clocks SPI_TPM_CLK] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
        [get_cells -filter "@is_sequential" top_earlgrey/u_spi_device/u_passthrough/cmd_info_reg_read_pipeline_mode*]]

##################
# SPI HOST clock #
##################
# SPI host core logic operates on the IO_CLK
#
# See https://docs.google.com/drawings/d/1qkUnXaRafIPyBnVpreqfbF_zSy0xlpHqXMZp6F-j8Cc/edit?usp=sharing
# During pre-layout, the SPI_HOST_CLK source latencies are estimated to account
# for pad and logic latencies. After CTS, source latency must be removed as all
# clocks are propagated.

# This requires knowledge of actual pin names, which are different depending on
# whether we run this with tech libs or not.
if {$FOUNDRY_ROOT != ""} {
    set REG_PIN  gen_flops[0]*.u_size_only_reg/Q
} else {
    set REG_PIN  q_o[0]
}

# cascaded generated clock on the port
create_generated_clock -name SPI_HOST_CLK -source [get_pins ${IO_CLK_PIN}] \
                       -divide_by 2 [get_ports SPI_HOST_CLK] -master_clock  IO_CLK -add

# Multi-cycle path to adjust the hold edge, since launch and capture edges are
# opposite in the SPI_HOST_CLK domain.
set_multicycle_path -setup 1 -start -from [get_clocks IO_CLK] -to [get_clocks SPI_HOST_CLK]
set_multicycle_path -hold  1 -start -from [get_clocks IO_CLK] -to [get_clocks SPI_HOST_CLK]

# set multicycle path for data going from SPI_HOST_CLK to logic
# the SPI host logic will read these paths at "full cycle"
set_multicycle_path -setup 2 -end -from [get_clocks SPI_HOST_CLK] -to [get_clocks IO_CLK]
set_multicycle_path -hold 1  -end -from [get_clocks SPI_HOST_CLK] -to [get_clocks IO_CLK]

# computed delays from connected device
# host in has 2x the pcb delay to account for delays on both outgoing clocks and incoming data
set SPI_HOST_OUT_DEL_MIN [expr ${STORAGE_HOLD_DEL}  - ${PCB_SKEW}]
set SPI_HOST_OUT_DEL_MAX [expr ${STORAGE_SETUP_DEL} + ${PCB_SKEW}]
set SPI_HOST_IN_DEL_MIN  [expr ${STORAGE_OUT_DEL_MIN}]
set SPI_HOST_IN_DEL_MAX  [expr ${STORAGE_OUT_DEL_MAX} + 2 * ${PCB_DEL}]

# bidir ports, with the downstream device launching on falling edge
set SPI_HOST_DATA_PORTS [get_ports SPI_HOST_D*]
if {$spec_constr} {
set_input_delay -min ${SPI_HOST_IN_DEL_MIN} ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_CLK -add_delay
set_input_delay -max ${SPI_HOST_IN_DEL_MAX} ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_CLK -add_delay
set_output_delay -min ${SPI_HOST_OUT_DEL_MIN} \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_CLK -add_delay
set_output_delay -max ${SPI_HOST_OUT_DEL_MAX} \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_CLK -add_delay
} else {
set_input_delay -min $spi_host_inp_min ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_CLK -add_delay
set_input_delay -max $spi_host_inp_max ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_CLK -add_delay
set_output_delay -min $spi_host_out_val_min \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_CLK -add_delay
set_output_delay -max $spi_host_out_val_max \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_CLK -add_delay
}

##########################################
# SPI DEV SLOW clock Passthru Operation  #
##########################################
# Passthrough target freq for slow commands is 24MHz. Using 25MHz to over-constrain
# For details on SPI passthrough timing, please see
# https://docs.google.com/presentation/d/1GEPxKaOsr9ZcJwI_MBEL74P7jQvBFzOdzSbgru_yVLQ/edit?usp=sharing
# See the SPI TPM section for half-cycle sampling with non-passthrough modes.
#
# The constraints below take the following approach:
# Define incoming passthrough clock on the SPI_DEV_CLK pin and relate all the inputs to it.
# Define also output delays since all pins are bidirectional.
# Define outgoing passthrough clock on the SPI_HOST_CLK pin but make sure it is a generated version
# of the incoming passthrough clock, relate the host side pins to this clock in both input/output
# directions.

set SPI_DEV_SLOW_PASS_TCK 40.0
set SPI_DEV_SLOW_PASS_TCK_HALF [expr ${SPI_DEV_SLOW_PASS_TCK} / 2]
create_clock -name SPI_DEV_SLOW_PASS_CLK -period ${SPI_DEV_SLOW_PASS_TCK} \
    [get_ports ${SPI_DEV_CLK_PIN}] -add
set_clock_uncertainty ${SETUP_CLOCK_UNCERTAINTY} [get_clocks SPI_DEV_SLOW_PASS_CLK]

# clocks used by spi device internally
create_generated_clock -name SPI_DEV_SLOW_PASS_IN_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 \
    -master_clock SPI_DEV_SLOW_PASS_CLK -add \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_in_buf/${CLK_PIN}]
create_generated_clock -name SPI_DEV_SLOW_PASS_OUT_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 -invert \
    -master_clock SPI_DEV_SLOW_PASS_CLK -add \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_out_buf/${CLK_PIN}]


# clocks accounting for propagation delay to the other side
create_generated_clock -name SPI_HOST_SLOW_PASS_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 \
    -master_clock SPI_DEV_SLOW_PASS_CLK -add \
    [get_ports SPI_HOST_CLK]

# The propagated properties are needed to ensure the passthrough clocks assume all passthrough delay.
# This is done specifically for the passthrough interface to get realistic timing even during
# pre-layout.
set_propagated_clock [get_clock SPI_DEV_SLOW_PASS_CLK]
set_propagated_clock [get_clock SPI_HOST_SLOW_PASS_CLK]

# bidir ports facing host, with full-cycle sampling at the upstream host
if {$spec_constr} {
# This is the fast passthrough mode: Check the direct timing paths from an upstream host to a downstream Flash device.
# SPI Device is defined as input and SPI Host is defined as output.
set_input_delay -min ${SPI_DEV_IN_DEL_MIN} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_SLOW_PASS_CLK -add_delay
set_input_delay -max ${SPI_DEV_IN_DEL_MAX} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_SLOW_PASS_CLK -add_delay
set_output_delay -min ${SPI_DEV_OUT_DEL_MIN_FC} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_SLOW_PASS_CLK -add_delay
set_output_delay -max ${SPI_DEV_OUT_DEL_MAX} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_SLOW_PASS_CLK -add_delay
} else {
# This is the slow passthrough mode: Check the direct timing paths from a downstream Flash device to an upstream host.
# SPI Device is defined as output only and SPI Host is defined as input.
# No set_input_delay constraints for SPI Device (these are applied for the fast passthrough mode and for other SPI modes).
set_output_delay -min $spi_slow_pass_soc_out_min ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_SLOW_PASS_CLK -add_delay
set_output_delay -max $spi_slow_pass_soc_out_max ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_SLOW_PASS_CLK -add_delay
}
set_multicycle_path -setup 2 -from [get_clocks SPI_DEV_SLOW_PASS_IN_CLK] \
    -to [get_clocks SPI_DEV_SLOW_PASS_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}]
#leonids updated based on interaction with Alex
set_multicycle_path -hold -end 1 -from [get_clocks SPI_DEV_SLOW_PASS_IN_CLK] \
    -to [get_clocks SPI_DEV_SLOW_PASS_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}]

# bidir ports facing storage device
if {$spec_constr} {
# This is the fast passthrough mode: Check the direct timing paths from an upstream host to a downstream Flash device.
# SPI Device is defined as input and SPI Host is defined as output.
set_input_delay -min ${SPI_HOST_IN_DEL_MIN} ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_SLOW_PASS_CLK -add_delay
set_input_delay -max ${SPI_HOST_IN_DEL_MAX} ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_SLOW_PASS_CLK -add_delay
set_output_delay -min ${SPI_HOST_OUT_DEL_MIN} \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_SLOW_PASS_CLK -add_delay
set_output_delay -max ${SPI_HOST_OUT_DEL_MAX} \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_SLOW_PASS_CLK -add_delay
} else {
# This is the slow passthrough mode: Check the direct timing paths from a downstream Flash device to an upstream host.
# SPI Device is defined as output only and SPI Host is defined as input.
# No set_output_delay constraints for SPI Host (these are applied for the fast passthrough mode and for other SPI modes).
set_input_delay -min $spi_slow_pass_flsh_in_min ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_SLOW_PASS_CLK -add_delay
set_input_delay -max $spi_slow_pass_flsh_in_max ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_SLOW_PASS_CLK -add_delay
}
# CSB clock from top-level port (added to SPI_DEV_CSB_CLK)
create_clock -name SPI_DEV_SLOW_PASS_CSB_CLK -add \
    -period [expr 2 * ${SPI_DEV_SLOW_PASS_TCK}] \
    -waveform "${SPI_DEV_SLOW_PASS_TCK_HALF} [expr ${SPI_DEV_SLOW_PASS_TCK_HALF} + ${SPI_DEV_SLOW_PASS_TCK}]" \
    [get_ports SPI_DEV_CS_L]
if {$spec_constr} {
set_clock_latency -source -min ${SPI_DEV_IN_DEL_MIN} \
    -clock SPI_DEV_SLOW_PASS_CSB_CLK [get_ports SPI_DEV_CS_L]
set_clock_latency -source -max ${SPI_DEV_IN_DEL_MAX} \
    -clock SPI_DEV_SLOW_PASS_CSB_CLK [get_ports SPI_DEV_CS_L]
} else {
set_clock_latency -source -min $spi_dev_inp_csb_min \
    -clock SPI_DEV_SLOW_PASS_CSB_CLK [get_ports SPI_DEV_CS_L]
set_clock_latency -source -max $spi_dev_inp_csb_max \
    -clock SPI_DEV_SLOW_PASS_CSB_CLK [get_ports SPI_DEV_CS_L]
}
set_propagated_clock [get_clock SPI_DEV_SLOW_PASS_CSB_CLK]

# CSB-clocked status bits to various negedge-triggered flops, especially in the
# serializer.
# Advance the hold edge by one cycle, since CSB changes nominally on the same
# edge as SPI_DEV_SLOW_PASS_OUT_CLK, but SPI_DEV_SLOW_PASS_OUT_CLK isn't
# actually toggling.
#set_ideal_network [get_pins top_earlgrey/u_spi_device/u_csb_rst_scan_mux/clk_o]
set_multicycle_path -hold -end -from [get_clocks SPI_DEV_SLOW_PASS_CSB_CLK] \
    -to [get_clocks SPI_DEV_SLOW_PASS_OUT_CLK] 1
# Because this section does full-cycle sampling, the same moving of the capture
# edge is needed for SPI_DEV_CSB_CLK -> SPI_DEV_D* hold analysis. The default
# falling edge of SPI_DEV_CLK would not be active.
set_multicycle_path -hold -end -from [get_clocks SPI_DEV_SLOW_PASS_CSB_CLK] \
    -to [get_clocks SPI_DEV_SLOW_PASS_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}] 1
# Relax the hold time constraint for the passthrough clock gate. Really this is
# to accommodate the gate for the inverted clock, which isn't active for the
# modes used for these constraints. However, it would be an okay outcome if the
# filter result reached the gate before even the 7th clock edge got out.
set_multicycle_path -hold -end 1 -from [get_clocks SPI_DEV_SLOW_PASS_CLK] \
    -to [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets top_earlgrey/u_spi_device/u_passthrough/sck_gate_en]]

##
# Remove hold analysis from the following paths to ports. Even though the pins
# can change before the prior data was latched upstream, their effect is held
# back by other logic on SPI_DEV_SLOW_PASS_OUT_CLK.
# Note: The final output logic equation must not permit glitches in the presence
# of changes on the listed pins. Otherwise, any hold time failures could be
# real.
##

# This path is from locality logic that is on the *_IN_CLK domain and selects
# between fixed values or the return-by-hw register value. The flopped bits
# settle in the middle of the command/address phase, many cycles before the
# data phase.
set_false_path -hold -from [get_clocks SPI_DEV_SLOW_PASS_IN_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_spi_tpm/miso_o]]]

# Remove scan paths for timing analysis
set_clock_sense -stop_propagation -clock SPI_DEV_SLOW_PASS_CLK [get_pins -leaf -filter "@pin_direction == in" -of_objects [get_nets -segments -of_objects [get_pins u_ast/u_scan_clk/in_i*]]]
set_false_path -from [get_clocks SPI_DEV_SLOW_PASS_CSB_CLK] \
    -through [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets -segments -of_objects \
            [get_pins u_ast/u_scan_rst_n/in_i*]]]

##########################################
# SPI DEV FAST clock Passthru Operation  #
##########################################
# Passthrough target freq for fast commands is 33MHz. Using 40MHz to over-constrain
# For details on SPI passthrough timing, please see
# https://docs.google.com/presentation/d/1GEPxKaOsr9ZcJwI_MBEL74P7jQvBFzOdzSbgru_yVLQ/edit?usp=sharing
# See the SPI TPM section for half-cycle sampling with non-passthrough modes.
#
# The constraints below take the following approach:
# Define incoming passthrough clock on the SPI_DEV_CLK pin and relate all the inputs to it.
# Define also output delays since all pins are bidirectional.
# Define outgoing passthrough clock on the SPI_HOST_CLK pin but make sure it is a generated version
# of the incoming passthrough clock, relate the host side pins to this clock in both input/output
# directions.

set SPI_DEV_FAST_PASS_TCK 25.0
set SPI_DEV_FAST_PASS_TCK_HALF [expr ${SPI_DEV_FAST_PASS_TCK} / 2]
create_clock -name SPI_DEV_FAST_PASS_CLK -period ${SPI_DEV_FAST_PASS_TCK} \
    [get_ports ${SPI_DEV_CLK_PIN}] -add
set_clock_uncertainty ${SETUP_CLOCK_UNCERTAINTY} [get_clocks SPI_DEV_FAST_PASS_CLK]

# clocks used by spi device internally
create_generated_clock -name SPI_DEV_FAST_PASS_IN_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 \
    -master_clock SPI_DEV_FAST_PASS_CLK -add \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_in_buf/${CLK_PIN}]
create_generated_clock -name SPI_DEV_FAST_PASS_OUT_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 -invert \
    -master_clock SPI_DEV_FAST_PASS_CLK -add \
    [get_pins top_earlgrey/u_spi_device/u_clk_spi_out_buf/${CLK_PIN}]


# clocks accounting for propagation delay to the other side
create_generated_clock -name SPI_HOST_FAST_PASS_CLK \
    -source [get_ports ${SPI_DEV_CLK_PIN}] -divide_by 1 \
    -master_clock SPI_DEV_FAST_PASS_CLK -add \
    [get_ports SPI_HOST_CLK]

# The propagated properties are needed to ensure the passthrough clocks assume all passthrough delay.
# This is done specifically for the passthrough interface to get realistic timing even during
# pre-layout.
set_propagated_clock [get_clock SPI_DEV_FAST_PASS_CLK]
set_propagated_clock [get_clock SPI_HOST_FAST_PASS_CLK]

# bidir ports facing host, with full-cycle sampling at the upstream host
if {$spec_constr} {
set_input_delay -min ${SPI_DEV_IN_DEL_MIN} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_FAST_PASS_CLK -add_delay
set_input_delay -max ${SPI_DEV_IN_DEL_MAX} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_FAST_PASS_CLK -add_delay
set_output_delay -min ${SPI_DEV_OUT_DEL_MIN_FC} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_FAST_PASS_CLK -add_delay
set_output_delay -max ${SPI_DEV_OUT_DEL_MAX} ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_FAST_PASS_CLK -add_delay
} else {
set_input_delay -min $spi_fast_pass_soc_in_min ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_FAST_PASS_CLK -add_delay
set_input_delay -max $spi_fast_pass_soc_in_max ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_FAST_PASS_CLK -add_delay
set_output_delay -min $spi_fast_pass_dev_out_val_min ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_FAST_PASS_CLK -add_delay
set_output_delay -max $spi_fast_pass_dev_out_val_max ${SPI_DEV_DATA_PORTS} \
    -clock_fall -clock SPI_DEV_FAST_PASS_CLK -add_delay
}
set_multicycle_path -setup 2 -from [get_clocks SPI_DEV_FAST_PASS_IN_CLK] \
    -to [get_clocks SPI_DEV_FAST_PASS_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}]
#leonids updated based on interaction with Alex
set_multicycle_path -hold -end 1 -from [get_clocks SPI_DEV_FAST_PASS_IN_CLK] \
    -to [get_clocks SPI_DEV_FAST_PASS_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}]

# bidir ports facing storage device
if {$spec_constr} {
set_input_delay -min ${SPI_HOST_IN_DEL_MIN} ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_FAST_PASS_CLK -add_delay
set_input_delay -max ${SPI_HOST_IN_DEL_MAX} ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_FAST_PASS_CLK -add_delay
set_output_delay -min ${SPI_HOST_OUT_DEL_MIN} \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_FAST_PASS_CLK -add_delay
set_output_delay -max ${SPI_HOST_OUT_DEL_MAX} \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_FAST_PASS_CLK -add_delay
} else {
set_input_delay -min $spi_fast_pass_host_inp_min ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_FAST_PASS_CLK -add_delay
set_input_delay -max $spi_fast_pass_host_inp_max ${SPI_HOST_DATA_PORTS} \
    -clock_fall -clock SPI_HOST_FAST_PASS_CLK -add_delay
set_output_delay -min $spi_fast_pass_flsh_out_min \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_FAST_PASS_CLK -add_delay
set_output_delay -max $spi_fast_pass_flsh_out_max \
    [get_ports "SPI_HOST_CS_L ${SPI_HOST_DATA_PORTS}"] \
    -clock SPI_HOST_FAST_PASS_CLK -add_delay
}
# Fast commands must use the fast read pipeline. Disable timing for the
# combinatorial passthrough path.
set_false_path -from [get_clocks SPI_HOST_FAST_PASS_CLK] \
    -through [get_ports ${SPI_DEV_DATA_PORTS}] \
    -to [get_clocks SPI_DEV_FAST_PASS_CLK]

#leonids 03/06/2024 Updated based on interaction with Alex
# full-cycle sampling flops
set_false_path -from [get_clocks SPI_HOST_FAST_PASS_CLK] \
    -to [get_clocks SPI_DEV_FAST_PASS_IN_CLK]

# CSB clock from top-level port (added to SPI_DEV_CSB_CLK)
create_clock -name SPI_DEV_FAST_PASS_CSB_CLK -add \
    -period [expr 2 * ${SPI_DEV_FAST_PASS_TCK}] \
    -waveform "${SPI_DEV_FAST_PASS_TCK_HALF} [expr ${SPI_DEV_FAST_PASS_TCK_HALF} + ${SPI_DEV_FAST_PASS_TCK}]" \
    [get_ports SPI_DEV_CS_L]
if {$spec_constr} {
set_clock_latency -source -min ${SPI_DEV_IN_DEL_MIN} \
    -clock SPI_DEV_FAST_PASS_CSB_CLK [get_ports SPI_DEV_CS_L]
set_clock_latency -source -max ${SPI_DEV_IN_DEL_MAX} \
    -clock SPI_DEV_FAST_PASS_CSB_CLK [get_ports SPI_DEV_CS_L]
} else {
set_clock_latency -source -min $spi_dev_inp_csb_min \
    -clock SPI_DEV_FAST_PASS_CSB_CLK [get_ports SPI_DEV_CS_L]
set_clock_latency -source -max $spi_dev_inp_csb_max \
    -clock SPI_DEV_FAST_PASS_CSB_CLK [get_ports SPI_DEV_CS_L]
}
set_propagated_clock [get_clock SPI_DEV_FAST_PASS_CSB_CLK]

# CSB-clocked status bits to various negedge-triggered flops, especially in the
# serializer.
# Advance the hold edge by one cycle, since CSB changes nominally on the same
# edge as SPI_DEV_FAST_PASS_OUT_CLK, but SPI_DEV_FAST_PASS_OUT_CLK isn't
# actually toggling.
#set_ideal_network [get_pins top_earlgrey/u_spi_device/u_csb_rst_scan_mux/clk_o]
set_multicycle_path -hold -end -from [get_clocks SPI_DEV_FAST_PASS_CSB_CLK] \
    -to [get_clocks SPI_DEV_FAST_PASS_OUT_CLK] 1
# Because this section does full-cycle sampling, the same moving of the capture
# edge is needed for SPI_DEV_CSB_CLK -> SPI_DEV_D* hold analysis. The default
# falling edge of SPI_DEV_CLK would not be active.
set_multicycle_path -hold -end -from [get_clocks SPI_DEV_FAST_PASS_CSB_CLK] \
    -to [get_clocks SPI_DEV_FAST_PASS_CLK] -through [get_ports ${SPI_DEV_DATA_PORTS}] 1
# Relax the hold time constraint for the passthrough clock gate. Really this is
# to accommodate the gate for the inverted clock, which isn't active for the
# modes used for these constraints. However, it would be an okay outcome if the
# filter result reached the gate before even the 7th clock edge got out.
set_multicycle_path -hold -end 1 -from [get_clocks SPI_DEV_FAST_PASS_CLK] \
    -to [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets top_earlgrey/u_spi_device/u_passthrough/sck_gate_en]]

##
# Remove hold analysis from the following paths to ports. Even though the pins
# can change before the prior data was latched upstream, their effect is held
# back by other logic on SPI_DEV_FAST_PASS_OUT_CLK.
# Note: The final output logic equation must not permit glitches in the presence
# of changes on the listed pins. Otherwise, any hold time failures could be
# real.
##

# This path is from locality logic that is on the *_IN_CLK domain and selects
# between fixed values or the return-by-hw register value. The flopped bits
# settle in the middle of the command/address phase, many cycles before the
# data phase.
set_false_path -hold -from [get_clocks SPI_DEV_FAST_PASS_IN_CLK] \
    -to [get_ports ${SPI_DEV_DATA_PORTS}] \
    -through [get_pins -leaf -filter "@pin_direction == out" -of_objects \
               [get_nets -segments -of_objects \
                 [get_pins top_earlgrey/u_spi_device/u_spi_tpm/miso_o]]]

# Remove scan paths for timing analysis
set_clock_sense -stop_propagation -clock SPI_DEV_FAST_PASS_CLK [get_pins -leaf -filter "@pin_direction == in" -of_objects [get_nets -segments -of_objects [get_pins u_ast/u_scan_clk/in_i*]]]
set_false_path -from [get_clocks SPI_DEV_FAST_PASS_CSB_CLK] \
    -through [get_pins -leaf -filter "@pin_direction == in" -of_objects \
        [get_nets -segments -of_objects \
            [get_pins u_ast/u_scan_rst_n/in_i*]]]

# Alex Williams SPI_TPM constraints
set_false_path -from [get_clocks SPI_TPM_CLK] -through [get_pins -leaf -filter "@pin_direction == out" -of_objects [get_nets -segments -of_objects  [get_pins top_earlgrey/u_spi_device/u_s2p/data_valid_o]]]
set_false_path -from [get_clocks SPI_TPM_CLK] -through [get_pins -leaf -filter "@pin_direction == out" -of_objects [get_nets -segments -of_objects [get_pins top_earlgrey/u_spi_device/u_s2p/data_o*]]]
 set_false_path -from [get_clocks SPI_TPM_CLK] -to [get_pins -leaf -filter "@pin_direction == in" -of_objects [get_cells -filter "@is_sequential" top_earlgrey/u_spi_device/u_passthrough/*]]

#leonids updated based on interaction with Alex
set_multicycle_path -setup 2 -from [get_ports ${TPM_CSB_PORT}]     -to [get_clocks SPI_TPM_CLK]
set_multicycle_path -hold -end 1 -from [get_ports ${TPM_CSB_PORT}] -to [get_clocks SPI_TPM_CLK]


set_false_path -from [get_clocks SPI_DEV_CLK] -through [get_cells top_earlgrey/u_sysrst_ctrl_aon/*]
set_false_path -from [get_clocks SPI_DEV_HC_CLK] -through [get_cells top_earlgrey/u_sysrst_ctrl_aon/*]
set_false_path -from [get_clocks SPI_HOST_CLK] -through [get_cells top_earlgrey/u_sysrst_ctrl_aon/*]
set_false_path -from [get_clocks SPI_DEV_FAST_PASS_CLK] -through [get_cells top_earlgrey/u_sysrst_ctrl_aon/*] ; #leonids updated based on interaction with Alex

set_false_path -from SPI_HOST_D* -to SPI_HOST_D*
set_false_path -from SPI_DEV_D* -to SPI_DEV_D*
set_false_path -from SPI_DEV_CS_L -to SPI_DEV_D*

##########################################
# SPI HOST 1                             #
##########################################

# 1. Rework the blanket constraints for the muxed I/Os to only apply to the IO_DIV4_CLK IPs. Only SPI_HOST1 is on IO_DIV2_CLK, and its constraints are special:
# aggregate all IO banks
set IO_BANKS [get_ports IOA*]
append_to_collection IO_BANKS [get_ports IOB*]
append_to_collection IO_BANKS [get_ports IOC*]
append_to_collection IO_BANKS [get_ports IOR*]

# constrain muxed IOs running on IO_DIV4_CLK. Note that IO_DIV2_CLK is only used
# for SPI_HOST1, which has special constraints that are defined later.
set IO_IN_DEL_FRACTION 0.4
set IO_OUT_DEL_FRACTION 0.4

# IO_DIV4_CLK IPs are all either asynchronous or have a loose skew requirement.
# Constrain the max delay from reg to port and port to reg, and ignore hold time.
set IO_DIV4_IN_DEL    [expr ${IO_IN_DEL_FRACTION} * ${IO_TCK_PERIOD} * 4.0]
set IO_DIV4_OUT_DEL   [expr ${IO_OUT_DEL_FRACTION} * ${IO_TCK_PERIOD} * 4.0]

set_input_delay ${IO_DIV4_IN_DEL}   ${IO_BANKS} -clock IO_DIV4_CLK -add_delay
set_output_delay ${IO_DIV4_OUT_DEL} ${IO_BANKS} -clock IO_DIV4_CLK -add_delay

# 2. Create the generated clocks for SPI_HOST1, input and output delays, and multi-cycle paths just like SPI_HOST0. Place these after the SPI_HOST0 constraints.

###########################################
# SPI_HOST_1 timing (full-cycle sampling) #
###########################################
# Preferred sites for SPI HOST 1
set SPI_HOST1_CLK_PORT IOB3
set SPI_HOST1_DATA_PORTS "IOB0 IOB1 IOB2"

set SPI_HOST1_SRC_CLK [get_pins top_earlgrey/u_spi_host1/u_spi_core/u_fsm/u_sck_flop/*/clk_i]
set SPI_HOST1_DIV_CLK [get_pins top_earlgrey/u_spi_host1/u_spi_core/u_fsm/u_sck_flop/*/q_o[0]]

# First model the clock divider that generates a new frequency internally.
create_generated_clock -name SPI_HOST1_INTERNAL_CLK -divide_by 2 -add \
  -source ${SPI_HOST1_SRC_CLK} \
  -master_clock [get_clocks IO_DIV2_CLK] \
  [get_pins ${SPI_HOST1_DIV_CLK}]

# Then create a derived clock at the top-level port for input and output delays.
create_generated_clock -name SPI_HOST1_CLK -divide_by 1 -add \
  -source [get_pins ${SPI_HOST1_DIV_CLK}] \
  -master_clock [get_clocks SPI_HOST1_INTERNAL_CLK] \
  [get_ports ${SPI_HOST1_CLK_PORT}]

if {$spec_constr} {
set_input_delay  -clock SPI_HOST1_CLK -clock_fall -min ${SPI_HOST_IN_DEL_MIN} \
    [get_ports ${SPI_HOST1_DATA_PORTS}] -add_delay
set_input_delay  -clock SPI_HOST1_CLK -clock_fall -max ${SPI_HOST_IN_DEL_MAX} \
    [get_ports ${SPI_HOST1_DATA_PORTS}] -add_delay
set_output_delay -clock SPI_HOST1_CLK -min ${SPI_HOST_OUT_DEL_MIN} \
    [get_ports ${SPI_HOST1_DATA_PORTS}] -add_delay
set_output_delay -clock SPI_HOST1_CLK -max ${SPI_HOST_OUT_DEL_MAX} \
    [get_ports ${SPI_HOST1_DATA_PORTS}] -add_delay
} else {
set_input_delay -min $spi_host1_inp_min  [get_ports ${SPI_HOST1_DATA_PORTS}] \
    -clock_fall -clock SPI_HOST1_CLK -add_delay
set_input_delay -max $spi_host1_inp_max  [get_ports ${SPI_HOST1_DATA_PORTS}] \
    -clock_fall -clock SPI_HOST1_CLK -add_delay
set_output_delay -min $spi_host1_out_val_min \
    [get_ports ${SPI_HOST1_DATA_PORTS}] \
    -clock SPI_HOST1_CLK -add_delay
set_output_delay -max $spi_host1_out_val_max \
    [get_ports ${SPI_HOST1_DATA_PORTS}] \
    -clock SPI_HOST1_CLK -add_delay
}
# Multi-cycle path to adjust the hold edge, since launch and capture edges are
# opposite in the SPI_HOST1_CLK domain.
set_multicycle_path -setup -start 1 \
    -from [get_clocks IO_DIV2_CLK] \
    -to [get_clocks SPI_HOST1_CLK]
set_multicycle_path -hold -start 1 \
    -from [get_clocks IO_DIV2_CLK] \
    -to [get_clocks SPI_HOST1_CLK]

# set multicycle path for data going from SPI_HOST1_CLK to logic
# the SPI host logic will read these paths at "full cycle"
set_multicycle_path -setup -end 2 \
    -from [get_clocks SPI_HOST1_CLK] \
    -to [get_clocks IO_DIV2_CLK]
set_multicycle_path -hold -end 1 \
    -from [get_clocks SPI_HOST1_CLK] \
    -to [get_clocks IO_DIV2_CLK]

# 3. Adjust the asynchronous clock groups so SPI_HOST1_CLK is grouped with IO_DIV2_CLK.

# -    -group [get_clocks IO_DIV2_CLK                                  ] \
# +    -group [get_clocks {IO_DIV2_CLK SPI_HOST1_CLK}                  ] \

# Approved by Ziv
#  SPI_HOST_D0
set_false_path -hold -fall_through [get_pins u_padring/gen_dio_pads_9__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#  SPI_HOST_D1
set_false_path -hold -fall_through [get_pins u_padring/gen_dio_pads_10__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#  SPI_HOST_D2
set_false_path -hold -fall_through [get_pins u_padring/gen_dio_pads_11__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#  SPI_HOST_D3
set_false_path -hold -fall_through [get_pins u_padring/gen_dio_pads_12__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#  SPI_DEV_D0
set_false_path -hold -fall_through [get_pins u_padring/gen_dio_pads_15__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#  SPI_DEV_D1
set_false_path -hold -fall_through [get_pins u_padring/gen_dio_pads_16__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#  SPI_DEV_D2
set_false_path -hold -fall_through [get_pins u_padring/gen_dio_pads_17__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#  SPI_DEV_D3
set_false_path -hold -fall_through [get_pins u_padring/gen_dio_pads_18__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#IOB0
set_false_path -hold -fall_through [get_pins u_padring/gen_mio_pads_9__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#IOB1
set_false_path -hold -fall_through [get_pins u_padring/gen_mio_pads_10__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#IOB2
set_false_path -hold -fall_through [get_pins u_padring/gen_mio_pads_11__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]
#IOB3
set_false_path -hold -fall_through [get_pins u_padring/gen_mio_pads_12__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE]

# For SPI_HOST1, I/O timing is only closed on pads IOB0, IOB1, IOB2, and IOB3 (see below for details).
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOA0
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOA1
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOA2
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOA3
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOA4
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOA5
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOA6
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOA7
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOA8
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB10
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB11
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB12
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB4
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB5
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB6
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB7
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB8
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB9
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC0
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC1
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC10
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC11
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC12
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC2
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC3
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC4
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC5
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC6
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC7
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC8
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOC9
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR0
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR10
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR11
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR12
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR13
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR2
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR3
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR4
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR5
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR6
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOR7

set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -through IOB0 -to IO_DIV2_CLK
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -through IOB1 -to IO_DIV2_CLK
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -through IOB2 -to IO_DIV2_CLK
set_false_path  -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -through IOR1 -to IO_DIV2_CLK
set_false_path  -from SPI_HOST1_INTERNAL_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -through IOR1 -to IO_DIV2_CLK

## begin: SPI Host 1 constraints for PrimeTime

########################################
# SPI Host 1 constraints for PrimeTime #
########################################
# Note that these set_case_analysis and set_false_path constraints have not been used for synthesis but as PrimeTime waivers only.
if { $synopsys_program_name eq "pt_shell"  } {
# SPI_HOST1 CSB (MioOut 51 -> mux sel 54) drives IOB0 (MIO pad 9):
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_9/q[0]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_9/q[1]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_9/q[2]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_9/q[3]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_9/q[4]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_9/q[5]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_9/q[6]

# SPI_HOST1 SD0 (MioOut 38 -> mux sel 41) drives IOB1 (MIO pad 10):
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_10/q[0]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_10/q[1]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_10/q[2]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_10/q[3]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_10/q[4]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_10/q[5]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_10/q[6]

# IOB2 (MIO pad 11 -> mux sel 13) drives SPI_HOST1 SD1 (MioIn 39):
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_periph_insel_39/q[0]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_periph_insel_39/q[1]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_periph_insel_39/q[2]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_periph_insel_39/q[3]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_periph_insel_39/q[4]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_periph_insel_39/q[5]

# SPI_HOST1 does not drive IOB2.
set_false_path -from IO_DIV2_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -to IOB2

# SPI_HOST1 SCK (MioOut 50 -> mux 53) drives IOB3 (MIO pad 12):
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_12/q[0]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_12/q[1]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_12/q[2]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_12/q[3]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_12/q[4]
set_case_analysis 1 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_12/q[5]
set_case_analysis 0 top_earlgrey/u_pinmux_aon/u_reg/u_mio_outsel_12/q[6]

set_false_path  -from SPI_HOST1_INTERNAL_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -through IOB0 -to IO_DIV2_CLK
set_false_path  -from SPI_HOST1_INTERNAL_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -through IOB1 -to IO_DIV2_CLK
set_false_path  -from SPI_HOST1_INTERNAL_CLK -through [get_cells -hierarchical -filter "full_name =~ *u_spi_host1*"] -through IOB2 -to IO_DIV2_CLK

set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOA0
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOA1
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOA2
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOA3
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOA4
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOA5
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOA6
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOA7
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOA8
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOB10
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOB11
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOB12
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOB4
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOB5
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOB6
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOB7
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOB8
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOB9
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC0
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC1
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC10
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC11
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC12
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC2
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC3
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC4
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC5
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC6
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC7
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC8
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOC9
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR0
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR10
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR11
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR12
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR13
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR2
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR3
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR4
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR5
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR6
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR7
set_false_path  -from SPI_HOST1_INTERNAL_CLK -to   IOR1
}
## end: SPI Host 1 constraints for PrimeTime

set_false_path  -through   [get_pins -hierarchical -filter "full_name =~ *PI2C_33_50_T_DR/IE"] -through [get_pins -hierarchical -filter "full_name =~ *PI2C_33_50_T_DR/Y"]

#leonids 06Jul False path that prevent SPI report
set_false_path -from [get_clocks SPI*] -through [get_cells -hierarchical -filter "full_name =~ *u_ast_dft*"]

#leonids 06Jul24 updated based on interaction with Alex
# For the false clock-gating check, we could try something like this to remove the CSB "clock" from the analysis:
set_sense -stop_propagation  \
    -clocks SPI_DEV_CSB_CLK \
    [get_pins -leaf \
        -filter "@pin_direction == in and full_name =~ top_earlgrey/u_spi_device/u_passthrough/*" \
        -of_objects \
            [get_nets -segments -of_objects \
                [get_pins top_earlgrey/u_spi_device/u_passthrough/rst_ni] \
            ] \
    ]
set_sense -stop_propagation  \
    -clocks SPI_DEV_*PASS_CSB_CLK \
    [get_pins -leaf \
        -filter "@pin_direction == in and full_name =~ top_earlgrey/u_spi_device/u_passthrough/*" \
        -of_objects \
            [get_nets -segments -of_objects \
                [get_pins top_earlgrey/u_spi_device/u_passthrough/rst_ni] \
            ] \
    ]
#leonids updated constraints probided by Alex do not prevent repot - Temp use of the next set_disable_clock_gating_check
set_disable_clock_gating_check [get_cells -of_objects [gpo top_earlgrey/u_spi_device/u_passthrough/passthrough_o_csb]]

# SPI Slew Rate and Drive Strength Constraints

#  SPI_HOST_D0
set_case_analysis 0 u_padring/gen_dio_pads_9__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_9__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_9__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 0 u_padring/gen_dio_pads_9__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#  SPI_HOST_D1
set_case_analysis 0 u_padring/gen_dio_pads_10__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_10__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_10__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 0 u_padring/gen_dio_pads_10__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#  SPI_HOST_D2
set_case_analysis 0 u_padring/gen_dio_pads_11__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_11__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_11__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 0 u_padring/gen_dio_pads_11__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#  SPI_HOST_D3
set_case_analysis 0 u_padring/gen_dio_pads_12__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_12__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_12__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 0 u_padring/gen_dio_pads_12__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#  SPI_HOST_CLK
set_case_analysis 0 u_padring/gen_dio_pads_13__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_13__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_13__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 1 u_padring/gen_dio_pads_13__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
set_case_analysis 1 u_padring/gen_dio_pads_13__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE
#  SPI_HOST_CS_L
set_case_analysis 0 u_padring/gen_dio_pads_14__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_14__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_14__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 1 u_padring/gen_dio_pads_14__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
set_case_analysis 1 u_padring/gen_dio_pads_14__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/OE
#  SPI_DEV_D0
set_case_analysis 0 u_padring/gen_dio_pads_15__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_15__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_15__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 0 u_padring/gen_dio_pads_15__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#  SPI_DEV_D1
set_case_analysis 0 u_padring/gen_dio_pads_16__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_16__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_16__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 0 u_padring/gen_dio_pads_16__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#  SPI_DEV_D2
set_case_analysis 0 u_padring/gen_dio_pads_17__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_17__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_17__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 0 u_padring/gen_dio_pads_17__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#  SPI_DEV_D3
set_case_analysis 0 u_padring/gen_dio_pads_18__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_18__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_18__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 0 u_padring/gen_dio_pads_18__u_dio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#  SPI_DEV_CLK
set_case_analysis 0 u_padring/gen_dio_pads_19__u_dio_pad/gen_techlib_u_impl_techlib/gen_input_only_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_19__u_dio_pad/gen_techlib_u_impl_techlib/gen_input_only_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_19__u_dio_pad/gen_techlib_u_impl_techlib/gen_input_only_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 1 u_padring/gen_dio_pads_19__u_dio_pad/gen_techlib_u_impl_techlib/gen_input_only_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#  SPI_DEV_CS_L
set_case_analysis 0 u_padring/gen_dio_pads_20__u_dio_pad/gen_techlib_u_impl_techlib/gen_input_only_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_dio_pads_20__u_dio_pad/gen_techlib_u_impl_techlib/gen_input_only_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_dio_pads_20__u_dio_pad/gen_techlib_u_impl_techlib/gen_input_only_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
set_case_analysis 1 u_padring/gen_dio_pads_20__u_dio_pad/gen_techlib_u_impl_techlib/gen_input_only_u_pad_macro_PBIDIR_33_33_FS_DR/IS
#IOA7
# Open drain pads have just one drive strength bit.
set_case_analysis 1 u_padring/gen_mio_pads_7__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_od_compat_u_pad_macro_PI2C_33_50_T_DR/DS
set_case_analysis 1 u_padring/gen_mio_pads_7__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_od_compat_u_pad_macro_PI2C_33_50_T_DR/IS
#IOB0
set_case_analysis 0 u_padring/gen_mio_pads_9__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_mio_pads_9__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_mio_pads_9__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
#IOB1
set_case_analysis 0 u_padring/gen_mio_pads_10__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_mio_pads_10__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_mio_pads_10__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
#IOB2
set_case_analysis 0 u_padring/gen_mio_pads_11__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_mio_pads_11__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_mio_pads_11__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1
#IOB3
set_case_analysis 0 u_padring/gen_mio_pads_12__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/SR
set_case_analysis 1 u_padring/gen_mio_pads_12__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS0
set_case_analysis 1 u_padring/gen_mio_pads_12__u_mio_pad/gen_techlib_u_impl_techlib/gen_bidir_u_pad_macro_PBIDIR_33_33_FS_DR/DS1

####################
# SPI-specific CDC #
####################
# Only one mode can be active at a time.
set_clock_groups -physically_exclusive \
    -group {SPI_DEV_CLK SPI_DEV_IN_CLK SPI_DEV_OUT_CLK SPI_DEV_CSB_CLK} \
    -group {SPI_DEV_HC_CLK SPI_DEV_HC_IN_CLK SPI_DEV_HC_OUT_CLK SPI_DEV_HC_CSB_CLK} \
    -group {SPI_HOST_SLOW_PASS_CLK SPI_DEV_SLOW_PASS_CLK SPI_DEV_SLOW_PASS_IN_CLK SPI_DEV_SLOW_PASS_OUT_CLK SPI_DEV_SLOW_PASS_CSB_CLK} \
    -group {SPI_HOST_FAST_PASS_CLK SPI_DEV_FAST_PASS_CLK SPI_DEV_FAST_PASS_IN_CLK SPI_DEV_FAST_PASS_OUT_CLK SPI_DEV_FAST_PASS_CSB_CLK} \
    -group {SPI_TPM_CLK SPI_TPM_IN_CLK SPI_TPM_OUT_CLK}

#####################
# CDC               #
#####################
# SPI_DEV_CSB_CLK -> SPI_HOST_CLK
#
set SPI_DEV_CLKS "SPI_DEV_CLK SPI_DEV_IN_CLK SPI_DEV_OUT_CLK SPI_DEV_CSB_CLK"
set SPI_DEV_HC_CLKS "SPI_DEV_HC_CLK SPI_DEV_HC_IN_CLK SPI_DEV_HC_OUT_CLK SPI_DEV_HC_CSB_CLK"
set SPI_DEV_SLOW_PASS_CLKS "SPI_HOST_SLOW_PASS_CLK SPI_DEV_SLOW_PASS_CLK SPI_DEV_SLOW_PASS_IN_CLK SPI_DEV_SLOW_PASS_OUT_CLK SPI_DEV_SLOW_PASS_CSB_CLK"
set SPI_DEV_FAST_PASS_CLKS "SPI_HOST_FAST_PASS_CLK SPI_DEV_FAST_PASS_CLK SPI_DEV_FAST_PASS_IN_CLK SPI_DEV_FAST_PASS_OUT_CLK SPI_DEV_FAST_PASS_CSB_CLK"
set SPI_TPM_CLKS "SPI_TPM_CLK SPI_TPM_IN_CLK SPI_TPM_OUT_CLK"

# this may need some refinement (and max delay / skew needs to be constrained)
# note that internal CDCs that are not timed as a result of this set_clock_groups
# directive are being checked post-route to make sure they are within spec.
# see chip_earlgrey_asic_check_only.sdc.
set_clock_groups -name group1 -async                                  \
    -group [get_clocks MAIN_CLK                                     ] \
    -group [get_clocks USB_CLK                                      ] \
    -group [get_clocks "${SPI_DEV_CLKS} ${SPI_DEV_HC_CLKS} ${SPI_DEV_SLOW_PASS_CLKS} ${SPI_DEV_FAST_PASS_CLKS} ${SPI_TPM_CLKS}"] \
    -group [get_clocks {IO_CLK SPI_HOST_CLK}       ] \
    -group [get_clocks {IO_DIV2_CLK SPI_HOST1_CLK SPI_HOST1_INTERNAL_CLK} ] \
    -group [get_clocks IO_DIV4_CLK                                  ] \
    -group [get_clocks "JTAG_TCK RV_JTAG_TCK LC_JTAG_TCK"           ] \
    -group [get_clocks AON_CLK                                      ]

# UART loopback path can be considered to be a false path
set_false_path -through [get_pins top_earlgrey/u_uart*/cio_rx_i] -through [get_pins top_earlgrey/u_uart*/cio_tx_o]

# break all timing paths through bidirectional IO buffers (i.e., from output and oe to input buffer output)
set_false_path -through [get_pins *padring/*pad/*/oe_i] -through [get_pins *padring/*pad/*/in_o]
set_false_path -through [get_pins *padring/*pad/*/out_i] -through [get_pins *padring/*pad/*/in_o]

# break path through jtag mux
set_false_path -from [get_ports IOC7] -to [get_ports IOR*]

#####################
# I/O drive/load    #
#####################

# This is not needed by CDC runs
if {!$IS_CDC_RUN} {
    # attach load and drivers to IOs to get a more realistic estimate
    set_driving_cell -no_design_rule -lib_cell ${DRIVING_PAD} -pin ${DRIVING_PAD_PIN} [all_inputs]
    set_load [load_of ${LOAD_PAD_LIB}/${LOAD_PAD}/${LOAD_PAD_PIN}] [all_outputs]
}

###################################
# Size Only and Don't touch Cells #
###################################

# This is not needed by CDC runs
if {!$IS_CDC_RUN} {
    # this is for architectural clock buffers, inverters and muxes
    set_size_only -all_instances [get_cells -h *u_size_only*] true
    # do not touch pad cells
    set_dont_touch [get_cells -h *u_pad_macro*]
}
puts "Done applying constraints for top level"

##########################################
# Case analysis for quasi-static signals #
##########################################

# assume a value of 0 for the open drain pad attribute
set_case_analysis 0 [get_pins u_padring/*_pad/attr_i?od_en*]

#SPI propagation through flop
set_sense -stop_propagation top_earlgrey/u_spi_device/u_reg/u_control_mode/q_reg*/Q
set_sense -stop_propagation top_earlgrey/u_pinmux_aon/dio_pad_attr_q_reg_*__invert/Q
set_sense -stop_propagation top_earlgrey/u_pinmux_aon/dio_out_retreg_q_reg*/Q
set_sense -stop_propagation top_earlgrey/u_pinmux_aon/u_reg/u_dio_pad_sleep_status_en*/q_reg*/Q

set_false_path -from top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/u_prim_lc_sync_lc_dft_en/gen_flops_u_prim_flop_2sync/gen_generic_u_impl_generic/u_sync_2/gen_techlib_u_impl_techlib/gen_flops*_u_size_only_reg/CK -to [get_ports IO*]
set_false_path -from top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/u_prim_lc_sender_pinmux_hw_debug_en/gen_flops_u_prim_flop/u_secure_anchor_flop/gen_techlib_u_impl_techlib/gen_flops*_u_size_only_reg/CK -to [get_ports IO*]
set_false_path -from top_earlgrey/u_pinmux_aon/mio_pad_attr_q_reg_*input_disable/CK -to [get_ports IO*]
set_false_path -from top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/tap_strap_q_reg*/CK -to [get_ports IO*]
set_false_path -from top_earlgrey/u_pinmux_aon/mio_pad_attr_q_reg*invert/CK -to [get_ports IO*]
set_false_path -from top_earlgrey/u_pinmux_aon/mio_pad_attr_q_reg*input_disable/CK -to [get_ports IO*]
set_false_path -from top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/u_prim_lc_sender_pinmux_hw_debug_en/gen_flops_u_prim_flop/u_secure_anchor_flop/gen_techlib_u_impl_techlib/gen_flops_*u_size_only_reg/CK -to [get_ports IO*]
set_false_path -from top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/u_prim_lc_sync_lc_dft_en/gen_flops_u_prim_flop_2sync/gen_generic_u_impl_generic/u_sync_2/gen_techlib_u_impl_techlib/gen_flops_*u_size_only_reg/CK -to [get_ports IO*]
set_false_path -from top_earlgrey/u_pinmux_aon/u_pinmux_strap_sampling/tap_strap_q_reg*/CK -to [get_ports IO*]
set_false_path -from top_earlgrey/u_pinmux_aon/dio_pad_attr_q_reg*input_disable/CK -to [get_ports IO*]

if { $synopsys_program_name  == "pt_shell" } {
  set_max_delay 5 -from [get_pins top_earlgrey/u_usbdev/usbdev_impl/u_usb_fs_nb_pe/u_usb_fs_tx/u_*_flop/${FLOP_PATH}/Q] \
                  -to   [get_ports USB_*] -probe
  set_max_delay 5 -from [get_ports USB_*] \
                  -to   [get_pins top_earlgrey/u_usbdev/i_usbdev_iomux/cdc_io_to_usb/gen_generic_u_impl_generic/u_sync_1/gen_techlib_u_impl_techlib/gen_flops_0__gen_reset_to_0_u_size_only_reg/D] -probe
  set_max_delay -from ${IO_BANKS} -to ${IO_BANKS} -through [get_cells top_earlgrey/u_sysrst_ctrl_aon/*] ${SYSRST_MAXDELAY} -probe
}

set_clock_uncertainty -setup  ${SETUP_CLOCK_UNCERTAINTY} [get_clocks IO_DIV2_CLK]
set_clock_uncertainty -setup  ${SETUP_CLOCK_UNCERTAINTY} [get_clocks IO_DIV4_CLK]
