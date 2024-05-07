# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(
    "//rules/opentitan:defs.bzl",
    "cw310_params",
    "opentitan_test",
)
load(
    "//sw/device/silicon_creator/rom_ext/e2e/ownership:defs.bzl",
    "ownership_transfer_test",
)

package(default_visibility = ["//visibility:public"])

ownership_transfer_test(
    name = "transfer_any_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Any
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:activate_key)
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub)
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
)

ownership_transfer_test(
    name = "bad_unlock_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Any
            # NOTE: We use the wrong unlock key to test that the unlock operation fails.
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:activate_key)
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:activate_key)
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub)
            --expected-error=OwnershipInvalidSignature
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
)

ownership_transfer_test(
    name = "bad_activate_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Any
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            # NOTE: We use the wrong activate key to test that the activate operation fails.
            --activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:activate_key)
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub)
            --expected-error=OwnershipInvalidSignature
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
)

ownership_transfer_test(
    name = "bad_owner_block_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Any
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:activate_key)
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub)
            --corrupt-owner-block-signature=true
            --dual-owner-boot-check=false
            --expected-error=OwnershipInvalidInfoPage
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
)

ownership_transfer_test(
    name = "bad_app_key_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Any
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:activate_key)
            # NOTE: We use the wrong app key (fake instead of dummy) to test that we cannot boot
            # the test program after completing the transfer.
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:app_prod_pub)
            --expected-error=OwnershipKeyNotFound
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
)

ownership_transfer_test(
    name = "transfer_endorsed_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Endorsed
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            --next-owner-key-pub=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key_pub)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:activate_key)
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub)
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
)

ownership_transfer_test(
    name = "bad_endorsee_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Endorsed
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            # NOTE: We use the wrong next-owner-public-key to test that endorsee is rejected and the activate operation fails.
            --next-owner-key-pub=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:owner_key_pub)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:activate_key)
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub)
            --dual-owner-boot-check=false
            --expected-error=OwnershipInvalidInfoPage
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
)

ownership_transfer_test(
    name = "locked_update_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Update
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:owner_key)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:activate_key)
            # NOTE: We rotate the `fake` test owner's application key to the dummy key to test that
            #       we can execute code with the new key.
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub)
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
)

ownership_transfer_test(
    name = "bad_locked_update_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Update
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            # NOTE: We use the wrong owner key to test that the activate operation fails.
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:activate_key)
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:app_prod_pub)
            --dual-owner-boot-check=false
            --expected-error=OwnershipInvalidInfoPage
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
    rsa_key = {
        "//sw/device/silicon_creator/lib/ownership/keys/fake:app_prod": "app_prod",
    },
)

ownership_transfer_test(
    name = "bad_locked_update_no_exec_test",
    cw310 = cw310_params(
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-mode=Update
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:activate_key)

            # NOTE: We use the wrong owner key and the dummy app key (which the ownership_transfer_test rule
            #       uses for signing) to check that owner code execution is denied in the intermediate
            #       dual-owner state.
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub)
            --expected-error=OwnershipKeyNotFound
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
)
