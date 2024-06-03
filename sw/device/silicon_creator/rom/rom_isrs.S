// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hw/top_earlgrey/sw/autogen/top_earlgrey_memory.h"
#include "sw/device/lib/base/macros.h"
#include "flash_ctrl_regs.h"

.equ LOAD_ACCESS_FAULT, 5

// If we get an ECC error reading from internal flash, one of these bits
// will be set in the flash controller's FAULT_STATUS register.
.equ PHY_ERRORS, (1 << FLASH_CTRL_FAULT_STATUS_PHY_STORAGE_ERR_BIT) | \
                 (1 << FLASH_CTRL_FAULT_STATUS_PHY_RELBL_ERR_BIT)

// NOTE: The "ax" flag below is necessary to ensure that this section
// is allocated executable space in ROM by the linker.
.section .rom_isrs, "ax"

// -----------------------------------------------------------------------------

  /**
   * Exception handler.
   */
  .balign 4
  .global rom_exception_handler_entry
  .type rom_exception_handler_entry, @function
rom_exception_handler_entry:
  // Save all registers to the stack.
  addi sp, sp, -OT_CONTEXT_SIZE
  sw   t0,  2 * OT_WORD_SIZE(sp)
  sw   t1,  3 * OT_WORD_SIZE(sp)
  sw   t2,  4 * OT_WORD_SIZE(sp)
  sw   t3,  5 * OT_WORD_SIZE(sp)

  /**
   * Compute the MEPC of the instruction after the fault.
   *
   * Since we support the RISC-V compressed instructions extension, we need to
   * check if the two least significant bits of the instruction are
   * b11 (0x3), which means that the trapped instruction is not compressed,
   * i.e., the trapped instruction is 32bits = 4bytes. Otherwise, the trapped
   * instruction is 16bits = 2bytes.
   */
  csrr t0, mepc
  lh t2, 0(t0)
  addi t0, t0, OT_HALF_WORD_SIZE
  li t1, 0x3
  and t3, t2, t1
  bne t3, t1, .L_rom_16bit_trap_instr
  // We already added one half word, so for a 32-bit instruction, add another.
  addi t0, t0, OT_HALF_WORD_SIZE
.L_rom_16bit_trap_instr:

  // Get the mcause, mask the reason and check that it is LoadAccessFault.
  csrr t1, mcause
  andi t1, t1, 31
  li t2, LOAD_ACCESS_FAULT
  bne t1, t2, .L_not_a_flash_error

  // Check if there is a flash error.
  li t3, TOP_EARLGREY_FLASH_CTRL_CORE_BASE_ADDR
  lw t1, FLASH_CTRL_FAULT_STATUS_REG_OFFSET(t3)
  andi t1, t1, PHY_ERRORS
  beqz t1, .L_not_a_flash_error

  // Clear the flash error.
  sw t1, FLASH_CTRL_FAULT_STATUS_REG_OFFSET(t3)

  // Exception handler exit and return to C:
  // Load the correct MEPC for the next instruction in the current task.
  csrw mepc, t0

  // Restore all registers from the stack.
  lw   t0,  2 * OT_WORD_SIZE(sp)
  lw   t1,  3 * OT_WORD_SIZE(sp)
  lw   t2,  4 * OT_WORD_SIZE(sp)
  lw   t3,  5 * OT_WORD_SIZE(sp)
  addi sp, sp, OT_CONTEXT_SIZE
  mret

.L_not_a_flash_error:
  j rom_interrupt_handler

  .size rom_exception_handler_entry, .-rom_exception_handler_entry
