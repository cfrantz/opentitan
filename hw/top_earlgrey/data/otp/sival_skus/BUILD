# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# SKU: SiVal Bringup. ASCII code `SV00`.
# The SiVal bringup SKU is intended to be use in early bring-up stages of
# Earl Grey silicon. Some of the countermeasures in the ROM are disabled to
# de-risk bring-up and provisioning tests.

load(
    "//rules:const.bzl",
    "CONST",
    "EARLGREY_ALERTS",
    "EARLGREY_LOC_ALERTS",
)
load(
    "//rules:otp.bzl",
    "OTP_SIGVERIFY_FAKE_KEYS",
    "otp_alert_classification",
    "otp_alert_digest",
    "otp_hex",
    "otp_image_consts",
    "otp_json",
    "otp_partition",
    "otp_per_class_bytes",
    "otp_per_class_ints",
    "otp_per_class_lists",
)

package(default_visibility = ["//visibility:public"])

otp_json(
    name = "otp_json_creator_sw_cfg",
    partitions = [
        otp_partition(
            name = "CREATOR_SW_CFG",
            items = {
                # Enable AST initialization.
                # CREATOR_SW_CFG_AST_CFG is handled by the manufacturing flow
                # and not listed directly in this configuration.
                "CREATOR_SW_CFG_AST_INIT_EN": otp_hex(CONST.MUBI4_TRUE),
                "CREATOR_SW_CFG_ROM_EXT_SKU": otp_hex(0x0),
                # TODO(#26060): Temporarily disable SPX verification.
                # Disable SPX+ signature verification. See the definitions of
                # `kSigverifySpxDisabledOtp` in
                # sw/device/silicon_creator/lib/sigverify/spx_verify.h for
                # details on how to enable this feature.
                "CREATOR_SW_CFG_SIGVERIFY_SPX_EN": otp_hex(0x8d6c8c17),
                # Enable flash data page scrambling and ECC.
                "CREATOR_SW_CFG_FLASH_DATA_DEFAULT_CFG": "0000090606",
                "CREATOR_SW_CFG_FLASH_INFO_BOOT_DATA_CFG": otp_hex(0x0),
                "CREATOR_SW_CFG_FLASH_HW_INFO_CFG_OVERRIDE": otp_hex(0x0),
                # Disable use of entropy for countermeasures. See the definition
                # of `hardened_bool_t` in sw/device/lib/base/hardened.h.
                "CREATOR_SW_CFG_RNG_EN": otp_hex(CONST.HARDENED_FALSE),
                "CREATOR_SW_CFG_JITTER_EN": otp_hex(CONST.MUBI4_FALSE),
                "CREATOR_SW_CFG_RET_RAM_RESET_MASK": otp_hex(0x0),
                "CREATOR_SW_CFG_MANUF_STATE": otp_hex(CONST.MANUF_STATE.PERSONALIZED),
                # ROM execution is enabled if this item is set to a non-zero
                # value.
                "CREATOR_SW_CFG_ROM_EXEC_EN": otp_hex(0xffffffff),
                # Value to write to the cpuctrl CSR in `rom_init()`.
                # See:
                # https://ibex-core.readthedocs.io/en/latest/03_reference/cs_registers.html#cpu-control-register-cpuctrl
                # CPUCTRL = 0x1 enables ICACHE.
                "CREATOR_SW_CFG_CPUCTRL": otp_hex(0x1),
                # Value of the min_security_version_rom_ext field of the
                # default boot data.
                "CREATOR_SW_CFG_MIN_SEC_VER_ROM_EXT": otp_hex(0x0),
                # Value of the min_security_version_bl0 field of the default
                # boot data.
                "CREATOR_SW_CFG_MIN_SEC_VER_BL0": otp_hex(0x0),
                # Enable the default boot data in PROD and PROD_END life cycle
                # states. See the definition of `hardened_bool_t` in
                # sw/device/lib/base/hardened.h.
                "CREATOR_SW_CFG_DEFAULT_BOOT_DATA_IN_PROD_EN": otp_hex(CONST.HARDENED_TRUE),
                # This enables a busyloop in the ROM to give time to
                # trigger an RMA lifecycle transition via JTAG.
                # TODO: The following value needs to be updated once we have an
                # idea of how many cycles are needed to enter RMA.
                "CREATOR_SW_CFG_RMA_SPIN_EN": otp_hex(CONST.HARDENED_TRUE),
                "CREATOR_SW_CFG_RMA_SPIN_CYCLES": otp_hex(0x2000000),
                # Entropy source health check default values. This needs to be
                # populated when `CREATOR_SW_CFG_RNG_EN` is set to true.
                "CREATOR_SW_CFG_RNG_REPCNT_THRESHOLDS": otp_hex(0xffffffff),
                "CREATOR_SW_CFG_RNG_REPCNTS_THRESHOLDS": otp_hex(0xffffffff),
                "CREATOR_SW_CFG_RNG_ADAPTP_HI_THRESHOLDS": otp_hex(0xffffffff),
                "CREATOR_SW_CFG_RNG_ADAPTP_LO_THRESHOLDS": otp_hex(0x0),
                "CREATOR_SW_CFG_RNG_BUCKET_THRESHOLDS": otp_hex(0xffffffff),
                "CREATOR_SW_CFG_RNG_MARKOV_HI_THRESHOLDS": otp_hex(0xffffffff),
                "CREATOR_SW_CFG_RNG_MARKOV_LO_THRESHOLDS": otp_hex(0x0),
                "CREATOR_SW_CFG_RNG_EXTHT_HI_THRESHOLDS": otp_hex(0xffffffff),
                "CREATOR_SW_CFG_RNG_EXTHT_LO_THRESHOLDS": otp_hex(0x0),
                "CREATOR_SW_CFG_RNG_ALERT_THRESHOLD": otp_hex(0xfffd0002),
                "CREATOR_SW_CFG_RNG_HEALTH_CONFIG_DIGEST": otp_hex(0x8264cf75),

                # Any value different than `CONST.HARDENED_FALSE` will force
                # main SRAM scramble key rotation.
                "CREATOR_SW_CFG_SRAM_KEY_RENEW_EN": otp_hex(0x0),

                # Disable the use of the ROM_EXT immutable section.
                "CREATOR_SW_CFG_IMMUTABLE_ROM_EXT_EN": otp_hex(CONST.HARDENED_FALSE),
            },
        ),
    ],
)

otp_json(
    name = "otp_json_owner_sw_cfg",
    partitions = [
        otp_partition(
            name = "OWNER_SW_CFG",
            items = {
                # Report errors without any redaction.
                "OWNER_SW_CFG_ROM_ERROR_REPORTING": otp_hex(CONST.SHUTDOWN.REDACT.NONE),
                # Enable bootstrap. See `hardened_bool_t` in
                # sw/device/lib/base/hardened.h.
                "OWNER_SW_CFG_ROM_BOOTSTRAP_DIS": otp_hex(CONST.HARDENED_FALSE),
                # Set the enables to kAlertEnableNone.
                # See `alert_enable_t` in
                # sw/device/silicon_creator/lib/drivers/alert.h
                "OWNER_SW_CFG_ROM_ALERT_CLASS_EN": otp_per_class_bytes(
                    A = CONST.ALERT.NONE,
                    B = CONST.ALERT.NONE,
                    C = CONST.ALERT.NONE,
                    D = CONST.ALERT.NONE,
                ),
                # Set the escalation policies to kAlertEscalateNone.
                # See `alert_escalate_t` in
                # sw/device/silicon_creator/lib/drivers/alert.h
                "OWNER_SW_CFG_ROM_ALERT_ESCALATION": otp_per_class_bytes(
                    A = CONST.ALERT.ESC_NONE,
                    B = CONST.ALERT.ESC_NONE,
                    C = CONST.ALERT.ESC_NONE,
                    D = CONST.ALERT.ESC_NONE,
                ),
                # Set the classifications to kAlertClassX.
                # See `alert_class_t` in
                # sw/device/silicon_creator/lib/drivers/alert.h
                "OWNER_SW_CFG_ROM_ALERT_CLASSIFICATION": otp_alert_classification(
                    alert_list = EARLGREY_ALERTS,
                    # The ordering is "prod, prod_end, dev, rma"
                    default = "X, X, X, X",
                ),
                # Set the classifications to kAlertClassX. See `alert_class_t` in
                # sw/device/silicon_creator/lib/drivers/alert.h
                "OWNER_SW_CFG_ROM_LOCAL_ALERT_CLASSIFICATION": otp_alert_classification(
                    alert_list = EARLGREY_LOC_ALERTS,
                    # The ordering is "prod, prod_end, dev, rma"
                    default = "X, X, X, X",
                ),
                # Set the alert accumulation thresholds to 0 per class.
                "OWNER_SW_CFG_ROM_ALERT_ACCUM_THRESH": otp_per_class_ints(
                    A = 0,
                    B = 0,
                    C = 0,
                    D = 0,
                ),
                # Set the alert timeout cycles to 0 per class.
                "OWNER_SW_CFG_ROM_ALERT_TIMEOUT_CYCLES": otp_per_class_ints(
                    A = 0,
                    B = 0,
                    C = 0,
                    D = 0,
                ),
                # Set the alert phase cycles to 0,10,10,0xFFFFFFFF for classes
                # A and B, and to all zeros for classes C and D.
                "OWNER_SW_CFG_ROM_ALERT_PHASE_CYCLES": otp_per_class_lists(
                    A = "0x0, 0xa, 0xa, 0xffffffff",
                    B = "0x0, 0xa, 0xa, 0xffffffff",
                    C = "0x0, 0x0, 0x0, 0x0",
                    D = "0x0, 0x0, 0x0, 0x0",
                ),
                "OWNER_SW_CFG_ROM_WATCHDOG_BITE_THRESHOLD_CYCLES": otp_hex(0x0),
                # Set to 0x739 to use the OTP hash measurement of the software
                # readable OTP partitions as the key manager attestation binding
                # value. Since our attestation scheme is not finalized, we keep
                # this unprovisioned (disabled).
                "OWNER_SW_CFG_ROM_KEYMGR_OTP_MEAS_EN": otp_hex(0x0),
                "OWNER_SW_CFG_MANUF_STATE": otp_hex(0x0),
                "OWNER_SW_CFG_ROM_RSTMGR_INFO_EN": otp_hex(0x0),
                # Disable ROM_EXT recovery feature.
                "OWNER_SW_CFG_ROM_EXT_BOOTSTRAP_EN": otp_hex(0x0),
                # Disable SRAM readback for both ret-ram and main sram.
                "OWNER_SW_CFG_ROM_SRAM_READBACK_EN": otp_hex(CONST.MUBI4_FALSE << 4 | CONST.MUBI4_FALSE),
                "OWNER_SW_CFG_ROM_PRESERVE_RESET_REASON_EN": otp_hex(CONST.HARDENED_FALSE),
                "OWNER_SW_CFG_ROM_RESET_REASON_CHECK_VALUE": otp_hex(CONST.HARDENED_FALSE << 16 | CONST.HARDENED_FALSE),
                "OWNER_SW_CFG_ROM_FLASH_ECC_EXC_HANDLER_EN": otp_hex(CONST.HARDENED_TRUE),
                # By default, the sensor_ctrl should disable all sensors and mark
                # alerts as recoverable.
                "OWNER_SW_CFG_ROM_SENSOR_CTRL_ALERT_CFG": [
                    otp_hex(0x69696969),
                    otp_hex(0x69696969),
                    otp_hex(0x69696969),
                ],
            },
        ),
    ],
)

# Create an overlay for the alert_handler digest.
otp_alert_digest(
    name = "alert_digest_cfg",
    otp_img = ":otp_json_owner_sw_cfg",
)

# OTP *_SW_CFG and ROT_CREATOR_AUTH_* constants used to generate an FT
# individualization binary.
otp_image_consts(
    name = "otp_consts_c_file",
    src = "//hw/top_earlgrey/data/otp:otp_json_baseline",
    mmap_def = "//hw/top_earlgrey/data/otp:otp_ctrl_mmap.hjson",
    # TODO: Replace `OTP_SIGVERIFY_FAKE_KEYS` for real keys once they are
    # available.
    overlays = [
        ":alert_digest_cfg",
        ":otp_json_creator_sw_cfg",
        ":otp_json_owner_sw_cfg",
    ] + OTP_SIGVERIFY_FAKE_KEYS,
)

# Library containing {CREATOR,OWNER}_SW_CFG and
# ROT_CREATOR_AUTH_{CODESIGN,STATE} partition constants.
cc_library(
    name = "otp_consts",
    srcs = [":otp_consts_c_file"],
    deps = [
        "//hw/top:otp_ctrl_c_regs",
        "//sw/device/silicon_creator/manuf/lib:otp_img_types",
    ],
)
