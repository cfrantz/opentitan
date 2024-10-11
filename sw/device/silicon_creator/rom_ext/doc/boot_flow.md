# Boot Flows

## ROM_EXT Boot to Owner Firmware

The following diagram focuses on the ROM_EXT boot stage.

```mermaid
flowchart TB
subgraph container["<font size=6>Boot Flow</font>"]
direction TB
subgraph reset[" "]
    direction TB
    start((Reset)) --> flash_secrets[
        <b>Creator/Owner Secrets</b>
        Stage creator/owner secrets from flash to keymgr
    ]
    flash_secrets
end
subgraph rom[<b>ROM</b>]
    direction TB
    rom_measurements[
        <b>Measurements</b>
        Hardware measurment
        ROM_EXT measurement
    ]
end
subgraph rom_ext["<b>ROM_EXT</b>"]
    direction TB
    attest1[
        <b>Creator Attestation</b>
        Hardware: UDS cert
        ROM_EXT: CDI_0 cert
    ] --> owner_init[
        <b>Ownership Init</b>
        Derive owner sealing key
    ]
    owner_init -->|state=LockedOwner| locked_owner[
        Check Seals & Redundancy
    ]
    owner_init -->|state=Unlocked*| unlocked[
        Check current owner seal
        Check next owner signature
    ]
    owner_init -->|state=No Owner| invalid_owner[
        <b>Recovery</b>
        <code>sku_creator_owner_init</code> exists?
    ]
    invalid_owner -->|Yes| owner_init
    
    locked_owner --> boot_svc
    unlocked --> boot_svc
    invalid_owner --> boot_svc
    boot_svc[<b>Boot Services</b>] --> rescue

    rescue{Rescue?}

    rescue -->|No| verify
    rescue -->|Yes| rescue_mode

    rescue_mode[
        <b>Enter Rescue</b>
        Rescue Protocol
    ] --> fault
    

    verify[
        <b>Verify Owner Firmware</b>
        Select owner slot
        Find verification keys
        Verify
    ]

    verify -->|Fail| fault
    verify -->|Success| boot

    boot[
        <b>Boot Owner</b>
        Owner Attestation: CDI_1
        Creator INFO lockdown
        OTP lockdown
        ePMP configuration
        Owner flash lockdown
    ]

    fault((
        <b>Reboot</b>
        Report fault code
        Reboot
    ))

end
subgraph owner["<b>Owner</b>"]
    applicaiton((<b>Application Firmware</b>))
end
reset --> rom
rom --> rom_ext
rom_ext --> owner
style container fill:none,stroke:black
end
```

Notes:
- The owner sealing key is derived at the CDI_0 stage.
- If `sku_creator_owner_init` exists and is called, the ownership state is re-evaluated aftewards.
- The CDI_1 state of `keymgr` is initialized with owner measurements.
  - When the chip is in the `LockedOwner` state, the CDI_1 sealing diversification constants are chosen based on the application key used to validate the owner firmware.
  - When the chip is in an `Unlocked` state, the CDI_1 sealing diversification constant is set to `[0x55555555; 8]`.
- The OwnerSecret flash page is re-written upon successful activation of a new owner.
  - When the chip is in an `Unlocked` state, the CDI_1 attestation is derived from the current owner's key-ladder.
  - Upon tranistion from `Unlocked` to `LockedOwner`, the new OwnerSecret seed will cause the keymgr to derive different secrets.
    While the attestation in the `Unlocked` state may be trusted, that attestation is current owner's attestation.
    The attestation will become new owner's attestation after successful activation.

## Ownership State Transitions

The following diagram focuses on how ownership transfer manages ownership state transitions.
In the diagram:
- `state` refers to `ownership_state` in `boot_data`.
- `mode` refers to `update_mode` in the owner configuration.


```mermaid
flowchart TD
    boot((Boot))

    boot -->|state==<code>LockedOwner</code>| lo_mode
    lo_mode{mode == <code>NewVersion</code>
        and
        New <code>config_version</code>?
    }
    lo_mode -->|No| redundancy[
        <b>Check Redundancy</b>
        Check seals on PAGE_0 & 1
        Ensure rendundant copies
    ]
    redundancy --> unlock{
        <b>Boot Svc</b>
        Unlock?
    }

    lo_mode -->|Yes| lo_valid[
        <b>Validate PAGE_1</b>
        Check signature.
        Seal PAGE_1
        Ensure rendundant copies
    ]
    lo_valid --> unlock

    unlock -->|Good Signature
        and
        mode == OPEN| unlock_state[
        <b>Update State</b>
        state = <code>Unlocked</code>
    ]
    unlock -->|Bad Signature
        or
        mode == NewVersion| unlock_fail[<b>Report Error</b>
        Fail to Unlock
    ]
    unlock -->|No| rescue
    unlock_state --> reset
    unlock_fail --> reset

    reset((Reset))
    rescue{<b>Rescue?</b>}
    rescue -->|Yes| rescue_protocol[
        <b>Enter Rescue</b>
        Rescue Protocol
    ]
    rescue -->|No| update_mode
    rescue_protocol --> reset

    
    boot -->|state==<code>Unlocked</code>| un_mode
    un_mode[
        <b>Validate</b>
        Check seal on PAGE_0
        Check signature on PAGE_1
        Check state-specific criteria
    ]
    
    un_mode --> activate{
        <b>Boot Svc</b>
        Activate?
    }
    activate -->|Good Signature
        and
        PAGE_1 Valid| activate_owner
    activate -->|Bad Signature
        or
        PAGE_1 Invalid| activate_fail
    activate -->|No| rescue

    activate_owner[
        <b>Activate Owner</b>
        Seal PAGE_1
        Rewrite PAGE_0 & PAGE_1
        Regenerate OwnerSecret in flash
        state = LockedOwner
    ]
    activate_owner --> reset
    activate_fail[
        <b>Report Error</b>
        Fail to Activate
    ]
    activate_fail --> reset

    boot -->|state==<code>None</code>| recov_mode
    recov_mode{
        <b>No Valid Owner</b>
        <code>sku_creator_owner_init</code>
        exists?
    }
    recov_mode -->|Yes| sku_creator_owner_init
    sku_creator_owner_init[
        <b>SKU Recovery</b>
        Write pre-defined owner
        to PAGE_0
    ] --> lo_mode
    recov_mode -->|No| unlock_recov{
        <b>Boot Svc</b>
        Unlock?
    }
    unlock_recov -->|No| rescue
    unlock_recov -->|Signed With
         <code>NoOwnerRecoveryKey</code>| unlock_state
    update_mode{
        state == <code>Unlocked</code>
        or
        mode == <code>NewVersion</code>
    }
    update_mode -->|Yes| ownerlock0[
        <b>Owner Page Lock</b>
        PAGE_0 read-only
        PAGE_1 read-write
    ] --> lockdown
    update_mode -->|No| ownerlock1[
        <b>Owner Page Lock</b>
        PAGE_0 read-only
        PAGE_1 read-only
    ] --> lockdown

    lockdown[
        <b>Chip Lockdown</b>
    ] --> boot_owner((Boot Owner))
```
