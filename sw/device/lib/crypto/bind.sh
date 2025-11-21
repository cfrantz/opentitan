#!/bin/bash

# Bind cryptolib to rust via bindgen.

bindgen include/otcrypto.h -o otcrypto.rs \
    --use-core --no-derive-debug --no-layout-tests \
    --raw-line '#![allow(non_camel_case_types)]' \
    --raw-line '#![allow(non_upper_case_globals)]' \
    --allowlist-item="otcrypto_.*" \
    --allowlist-item="dice_.*" \
    -- -Dbool=uint8_t
