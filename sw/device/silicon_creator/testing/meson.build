# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# All tests added to this dictionary will result in build targets that have
# names starting `sw/device/tests/<test_name>`. They will not contain the
# subdirectory name, because the build targets are really declared at the bottom
# of this file, rather than in the subdirectories.
## mask_rom_tests = {
##   # 'test_name': {
##   #   'library': test_lib,
##   #   'dv_frames': true/false, # (can be omitted, defaults to `false`)
##   # },
## }

foreach mask_rom_test_name, mask_rom_test_info : mask_rom_tests
  foreach device_name, device_lib : sw_lib_arch_core_devices
    mask_rom_test_elf = executable(
      mask_rom_test_name + '_' + device_name,
      name_suffix: 'elf',
      dependencies: [
        riscv_crt,
        device_lib,
        mask_rom_test_info['library'],
        sw_lib_irq_handlers,
        sw_lib_testing_test_main,
      ],
    )

    mask_rom_test_embedded = custom_target(
      mask_rom_test_name + '_' + device_name,
      command: make_embedded_target_command,
      depend_files: [make_embedded_target_depend_files,],
      input: mask_rom_test_elf,
      output: make_embedded_target_outputs,
      build_by_default: true,
    )

    mask_rom_test_sim_dv_frames = []
    if device_name == 'sim_dv' and \
        mask_rom_test_info.has_key('dv_frames') and mask_rom_test_info['dv_frames']
      mask_rom_test_sim_dv_frames_bin = custom_target(
        mask_rom_test_name + '_sim_dv_frames_bin',
        command: [
          spiflash_bin,
          '--input=@INPUT@',
          '--dump-frames=@OUTPUT@',
        ],
        input: mask_rom_test_embedded[0],
        output: '@BASENAME@.frames.bin',
      )

      mask_rom_test_sim_dv_frames_vmem = custom_target(
        mask_rom_test_name + '_sim_dv_frames_vmem',
        command: [
          prog_srec_cat,
          '@INPUT@',
          '--binary',
          '--offset', '0x0',
          '--byte-swap', '4',
          '--fill', '0xff',
          '-within', '@INPUT@',
          '-binary',
          '-range-pad', '4',
          '--output', '@OUTPUT@',
          '--vmem',
        ],
        input: mask_rom_test_sim_dv_frames_bin,
        output: '@BASENAME@.vmem',
      )
      mask_rom_test_sim_dv_frames = [
        mask_rom_test_sim_dv_frames_bin,
        mask_rom_test_sim_dv_frames_vmem,
      ]
    endif

    mask_rom_test_sim_dv_logs = []
    if device_name == 'sim_dv'
      mask_rom_test_sim_dv_logs = custom_target(
        mask_rom_test_name + '_sim_dv_logs',
        command: extract_sw_logs_sim_dv_command,
        depend_files: [extract_sw_logs_sim_dv_depend_files,],
        input: mask_rom_test_elf,
        output: extract_sw_logs_sim_dv_outputs,
      )
    endif

    custom_target(
      mask_rom_test_name + '_export_' + device_name,
      command: export_target_command,
      depend_files: [export_target_depend_files,],
      input: [
        mask_rom_test_elf,
        mask_rom_test_embedded,
        mask_rom_test_sim_dv_frames,
        mask_rom_test_sim_dv_logs,
      ],
      output: mask_rom_test_name + '_export_' + device_name,
      build_always_stale: true,
      build_by_default: true,
    )
  endforeach
endforeach
