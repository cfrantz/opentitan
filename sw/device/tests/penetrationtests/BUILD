# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(":pentest.bzl", "pentest_cryptolib_fi_asym", "pentest_cryptolib_fi_sym", "pentest_cryptolib_sca_asym", "pentest_cryptolib_sca_sym", "pentest_fi", "pentest_fi_ibex", "pentest_fi_otbn", "pentest_sca")

package(default_visibility = ["//visibility:public"])

IBEX_FI_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:fi_ibex",
]

IBEX_FI_TESTVECTOR_ARGS = " ".join([
    "--fi-ibex-json=\"$(rootpath {})\"".format(target)
    for target in IBEX_FI_TESTVECTOR_TARGETS
])

pentest_fi_ibex(
    name = "fi_ibex",
    test_args = IBEX_FI_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/fi_ibex:harness",
    test_vectors = IBEX_FI_TESTVECTOR_TARGETS,
)

CRYPTO_FI_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:fi_crypto",
]

CRYPTO_FI_TESTVECTOR_ARGS = " ".join([
    "--fi-crypto-json=\"$(rootpath {})\"".format(target)
    for target in CRYPTO_FI_TESTVECTOR_TARGETS
])

pentest_fi(
    name = "fi_crypto",
    test_args = CRYPTO_FI_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/fi_crypto:harness",
    test_vectors = CRYPTO_FI_TESTVECTOR_TARGETS,
)

LCCTRL_FI_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:fi_lc_ctrl",
]

LCCTRL_FI_TESTVECTOR_ARGS = " ".join([
    "--fi-lc-ctrl-json=\"$(rootpath {})\"".format(target)
    for target in LCCTRL_FI_TESTVECTOR_TARGETS
])

pentest_fi(
    name = "fi_lc_ctrl",
    test_args = LCCTRL_FI_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/fi_lc_ctrl:harness",
    test_vectors = LCCTRL_FI_TESTVECTOR_TARGETS,
)

OTP_FI_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:fi_otp",
]

OTP_FI_TESTVECTOR_ARGS = " ".join([
    "--fi-otp-json=\"$(rootpath {})\"".format(target)
    for target in OTP_FI_TESTVECTOR_TARGETS
])

pentest_fi(
    name = "fi_otp",
    test_args = OTP_FI_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/fi_otp:harness",
    test_vectors = OTP_FI_TESTVECTOR_TARGETS,
)

RNG_FI_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:fi_rng",
]

RNG_FI_TESTVECTOR_ARGS = " ".join([
    "--fi-rng-json=\"$(rootpath {})\"".format(target)
    for target in RNG_FI_TESTVECTOR_TARGETS
])

pentest_fi(
    name = "fi_rng",
    test_args = RNG_FI_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/fi_rng:harness",
    test_vectors = RNG_FI_TESTVECTOR_TARGETS,
)

ROM_FI_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:fi_rom",
]

ROM_FI_TESTVECTOR_ARGS = " ".join([
    "--fi-rom-json=\"$(rootpath {})\"".format(target)
    for target in ROM_FI_TESTVECTOR_TARGETS
])

pentest_fi(
    name = "fi_rom",
    test_args = ROM_FI_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/fi_rom:harness",
    test_vectors = ROM_FI_TESTVECTOR_TARGETS,
)

OTBN_FI_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:fi_otbn",
]

OTBN_FI_TESTVECTOR_ARGS = " ".join([
    "--fi-otbn-json=\"$(rootpath {})\"".format(target)
    for target in OTBN_FI_TESTVECTOR_TARGETS
])

pentest_fi_otbn(
    name = "fi_otbn",
    test_args = OTBN_FI_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/fi_otbn:harness",
    test_vectors = OTBN_FI_TESTVECTOR_TARGETS,
)

AES_SCA_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:sca_aes",
]

AES_SCA_TESTVECTOR_ARGS = " ".join([
    "--sca-aes-json=\"$(rootpath {})\"".format(target)
    for target in AES_SCA_TESTVECTOR_TARGETS
])

pentest_sca(
    name = "sca_aes",
    test_args = AES_SCA_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/sca_aes:harness",
    test_vectors = AES_SCA_TESTVECTOR_TARGETS,
)

EDN_SCA_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:sca_edn",
]

EDN_SCA_TESTVECTOR_ARGS = " ".join([
    "--sca-edn-json=\"$(rootpath {})\"".format(target)
    for target in EDN_SCA_TESTVECTOR_TARGETS
])

pentest_sca(
    name = "sca_edn",
    test_args = EDN_SCA_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/sca_edn:harness",
    test_vectors = EDN_SCA_TESTVECTOR_TARGETS,
)

HMAC_SCA_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:sca_hmac",
]

HMAC_SCA_TESTVECTOR_ARGS = " ".join([
    "--sca-hmac-json=\"$(rootpath {})\"".format(target)
    for target in HMAC_SCA_TESTVECTOR_TARGETS
])

pentest_sca(
    name = "sca_hmac",
    test_args = HMAC_SCA_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/sca_hmac:harness",
    test_vectors = HMAC_SCA_TESTVECTOR_TARGETS,
)

IBEX_SCA_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:sca_ibex",
]

IBEX_SCA_TESTVECTOR_ARGS = " ".join([
    "--sca-ibex-json=\"$(rootpath {})\"".format(target)
    for target in IBEX_SCA_TESTVECTOR_TARGETS
])

pentest_sca(
    name = "sca_ibex",
    test_args = IBEX_SCA_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/sca_ibex:harness",
    test_vectors = IBEX_SCA_TESTVECTOR_TARGETS,
)

KMAC_SCA_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:sca_kmac",
]

KMAC_SCA_TESTVECTOR_ARGS = " ".join([
    "--sca-kmac-json=\"$(rootpath {})\"".format(target)
    for target in KMAC_SCA_TESTVECTOR_TARGETS
])

pentest_sca(
    name = "sca_kmac",
    test_args = KMAC_SCA_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/sca_kmac:harness",
    test_vectors = KMAC_SCA_TESTVECTOR_TARGETS,
)

OTBN_SCA_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:sca_otbn",
]

OTBN_SCA_TESTVECTOR_ARGS = " ".join([
    "--sca-otbn-json=\"$(rootpath {})\"".format(target)
    for target in OTBN_SCA_TESTVECTOR_TARGETS
])

pentest_sca(
    name = "sca_otbn",
    test_args = OTBN_SCA_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/sca_otbn:harness",
    test_vectors = OTBN_SCA_TESTVECTOR_TARGETS,
)

SHA3_SCA_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:sca_sha3",
]

SHA3_SCA_TESTVECTOR_ARGS = " ".join([
    "--sca-sha3-json=\"$(rootpath {})\"".format(target)
    for target in SHA3_SCA_TESTVECTOR_TARGETS
])

pentest_sca(
    name = "sca_sha3",
    test_args = SHA3_SCA_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/sca_sha3:harness",
    test_vectors = SHA3_SCA_TESTVECTOR_TARGETS,
)

CRYPTOLIB_FI_SYM_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:fi_sym_cryptolib",
]

CRYPTOLIB_FI_ASYM_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:fi_asym_cryptolib",
]

CRYPTOLIB_FI_SYM_TESTVECTOR_ARGS = " ".join([
    "--fi-sym-cryptolib-json=\"$(rootpath {})\"".format(target)
    for target in CRYPTOLIB_FI_SYM_TESTVECTOR_TARGETS
])

CRYPTOLIB_FI_ASYM_TESTVECTOR_ARGS = " ".join([
    "--fi-asym-cryptolib-json=\"$(rootpath {})\"".format(target)
    for target in CRYPTOLIB_FI_ASYM_TESTVECTOR_TARGETS
])

pentest_cryptolib_fi_sym(
    name = "fi_sym_cryptolib",
    slow_test = False,
    test_args = CRYPTOLIB_FI_SYM_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/fi_sym_cryptolib:harness",
    test_vectors = CRYPTOLIB_FI_SYM_TESTVECTOR_TARGETS,
)

pentest_cryptolib_fi_asym(
    name = "fi_asym_cryptolib",
    slow_test = False,
    test_args = CRYPTOLIB_FI_ASYM_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/fi_asym_cryptolib:harness",
    test_vectors = CRYPTOLIB_FI_ASYM_TESTVECTOR_TARGETS,
)

CRYPTOLIB_SCA_SYM_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:sca_sym_cryptolib",
]

CRYPTOLIB_SCA_ASYM_TESTVECTOR_TARGETS = [
    "//sw/host/penetrationtests/testvectors/data:sca_asym_cryptolib",
]

CRYPTOLIB_SCA_SYM_TESTVECTOR_ARGS = " ".join([
    "--sca-sym-cryptolib-json=\"$(rootpath {})\"".format(target)
    for target in CRYPTOLIB_SCA_SYM_TESTVECTOR_TARGETS
])

CRYPTOLIB_SCA_ASYM_TESTVECTOR_ARGS = " ".join([
    "--sca-asym-cryptolib-json=\"$(rootpath {})\"".format(target)
    for target in CRYPTOLIB_SCA_ASYM_TESTVECTOR_TARGETS
])

pentest_cryptolib_sca_sym(
    name = "sca_sym_cryptolib",
    slow_test = False,
    test_args = CRYPTOLIB_SCA_SYM_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/sca_sym_cryptolib:harness",
    test_vectors = CRYPTOLIB_SCA_SYM_TESTVECTOR_TARGETS,
)

pentest_cryptolib_sca_asym(
    name = "sca_asym_cryptolib",
    slow_test = False,
    test_args = CRYPTOLIB_SCA_ASYM_TESTVECTOR_ARGS,
    test_harness = "//sw/host/tests/penetrationtests/sca_asym_cryptolib:harness",
    test_vectors = CRYPTOLIB_SCA_ASYM_TESTVECTOR_TARGETS,
)
