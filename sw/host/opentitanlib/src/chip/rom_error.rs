// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use crate::with_unknown;
use std::error::Error;

with_unknown! {
    /// From `//sw/device/silicon_creator/lib/error.h`
    pub enum RomError: u32 [default = Self::Unknown] {
        /*
         * The following list of enumerators can be generated with:
         *
         $ bazel build //sw/host/opentitanlib/bindgen:rom_error
         $ cat bazel-bin/sw/host/opentitanlib/bindgen/rom_error__bindgen.rs \
              | grep const \
              | sed -E 's/^pub const (rom_error_kError([^:]+)).*$/\2 = bindgen::rom_error::\1,/g'
         */

        Ok = bindgen::rom_error::rom_error_kErrorOk,
        WriteBootdataThenReboot = bindgen::rom_error::rom_error_kErrorWriteBootdataThenReboot,
        Unknown = bindgen::rom_error::rom_error_kErrorUnknown,
        SigverifyBadRsaSignature = bindgen::rom_error::rom_error_kErrorSigverifyBadRsaSignature,
        SigverifyBadSpxSignature = bindgen::rom_error::rom_error_kErrorSigverifyBadSpxSignature,
        SigverifyBadKey = bindgen::rom_error::rom_error_kErrorSigverifyBadKey,
        SigverifyBadRsaKey = bindgen::rom_error::rom_error_kErrorSigverifyBadRsaKey,
        SigverifyBadSpxKey = bindgen::rom_error::rom_error_kErrorSigverifyBadSpxKey,
        SigverifyLargeRsaSignature = bindgen::rom_error::rom_error_kErrorSigverifyLargeRsaSignature,
        SigverifyBadEcdsaSignature = bindgen::rom_error::rom_error_kErrorSigverifyBadEcdsaSignature,
        SigverifyBadAuthPartition = bindgen::rom_error::rom_error_kErrorSigverifyBadAuthPartition,
        SigverifyBadEcdsaKey = bindgen::rom_error::rom_error_kErrorSigverifyBadEcdsaKey,
        KeymgrInternal = bindgen::rom_error::rom_error_kErrorKeymgrInternal,
        ManifestBadEntryPoint = bindgen::rom_error::rom_error_kErrorManifestBadEntryPoint,
        ManifestBadCodeRegion = bindgen::rom_error::rom_error_kErrorManifestBadCodeRegion,
        ManifestBadSignedRegion = bindgen::rom_error::rom_error_kErrorManifestBadSignedRegion,
        ManifestBadExtension = bindgen::rom_error::rom_error_kErrorManifestBadExtension,
        ManifestBadVersionMajor = bindgen::rom_error::rom_error_kErrorManifestBadVersionMajor,
        AlertBadIndex = bindgen::rom_error::rom_error_kErrorAlertBadIndex,
        AlertBadClass = bindgen::rom_error::rom_error_kErrorAlertBadClass,
        AlertBadEnable = bindgen::rom_error::rom_error_kErrorAlertBadEnable,
        AlertBadEscalation = bindgen::rom_error::rom_error_kErrorAlertBadEscalation,
        AlertBadCrc32 = bindgen::rom_error::rom_error_kErrorAlertBadCrc32,
        RomBootFailed = bindgen::rom_error::rom_error_kErrorRomBootFailed,
        Interrupt = bindgen::rom_error::rom_error_kErrorInterrupt,
        EpmpBadCheck = bindgen::rom_error::rom_error_kErrorEpmpBadCheck,
        KmacInvalidStatus = bindgen::rom_error::rom_error_kErrorKmacInvalidStatus,
        OtbnInvalidArgument = bindgen::rom_error::rom_error_kErrorOtbnInvalidArgument,
        OtbnBadOffsetLen = bindgen::rom_error::rom_error_kErrorOtbnBadOffsetLen,
        OtbnExecutionFailed = bindgen::rom_error::rom_error_kErrorOtbnExecutionFailed,
        OtbnSecWipeImemFailed = bindgen::rom_error::rom_error_kErrorOtbnSecWipeImemFailed,
        OtbnSecWipeDmemFailed = bindgen::rom_error::rom_error_kErrorOtbnSecWipeDmemFailed,
        OtbnBadInsnCount = bindgen::rom_error::rom_error_kErrorOtbnBadInsnCount,
        OtbnUnavailable = bindgen::rom_error::rom_error_kErrorOtbnUnavailable,
        FlashCtrlDataRead = bindgen::rom_error::rom_error_kErrorFlashCtrlDataRead,
        FlashCtrlInfoRead = bindgen::rom_error::rom_error_kErrorFlashCtrlInfoRead,
        FlashCtrlDataWrite = bindgen::rom_error::rom_error_kErrorFlashCtrlDataWrite,
        FlashCtrlInfoWrite = bindgen::rom_error::rom_error_kErrorFlashCtrlInfoWrite,
        FlashCtrlDataErase = bindgen::rom_error::rom_error_kErrorFlashCtrlDataErase,
        FlashCtrlInfoErase = bindgen::rom_error::rom_error_kErrorFlashCtrlInfoErase,
        FlashCtrlDataEraseVerify = bindgen::rom_error::rom_error_kErrorFlashCtrlDataEraseVerify,
        BootPolicyBadIdentifier = bindgen::rom_error::rom_error_kErrorBootPolicyBadIdentifier,
        BootPolicyBadLength = bindgen::rom_error::rom_error_kErrorBootPolicyBadLength,
        BootPolicyRollback = bindgen::rom_error::rom_error_kErrorBootPolicyRollback,
        BootstrapEraseAddress = bindgen::rom_error::rom_error_kErrorBootstrapEraseAddress,
        BootstrapProgramAddress = bindgen::rom_error::rom_error_kErrorBootstrapProgramAddress,
        BootstrapInvalidState = bindgen::rom_error::rom_error_kErrorBootstrapInvalidState,
        BootstrapNotRequested = bindgen::rom_error::rom_error_kErrorBootstrapNotRequested,
        BootstrapDisabledRomExt = bindgen::rom_error::rom_error_kErrorBootstrapDisabledRomExt,
        LogBadFormatSpecifier = bindgen::rom_error::rom_error_kErrorLogBadFormatSpecifier,
        BootDataNotFound = bindgen::rom_error::rom_error_kErrorBootDataNotFound,
        BootDataWriteCheck = bindgen::rom_error::rom_error_kErrorBootDataWriteCheck,
        BootDataInvalid = bindgen::rom_error::rom_error_kErrorBootDataInvalid,
        SpiDevicePayloadOverflow = bindgen::rom_error::rom_error_kErrorSpiDevicePayloadOverflow,
        AstInitNotDone = bindgen::rom_error::rom_error_kErrorAstInitNotDone,
        RstmgrBadInit = bindgen::rom_error::rom_error_kErrorRstmgrBadInit,
        RndBadCrc32 = bindgen::rom_error::rom_error_kErrorRndBadCrc32,
        BootSvcBadHeader = bindgen::rom_error::rom_error_kErrorBootSvcBadHeader,
        BootSvcBadSlot = bindgen::rom_error::rom_error_kErrorBootSvcBadSlot,
        RomExtBootFailed = bindgen::rom_error::rom_error_kErrorRomExtBootFailed,
        XModemTimeoutStart = bindgen::rom_error::rom_error_kErrorXModemTimeoutStart,
        XModemTimeoutPacket = bindgen::rom_error::rom_error_kErrorXModemTimeoutPacket,
        XModemTimeoutData = bindgen::rom_error::rom_error_kErrorXModemTimeoutData,
        XModemTimeoutCrc = bindgen::rom_error::rom_error_kErrorXModemTimeoutCrc,
        XModemTimeoutAck = bindgen::rom_error::rom_error_kErrorXModemTimeoutAck,
        XModemCrc = bindgen::rom_error::rom_error_kErrorXModemCrc,
        XModemEndOfFile = bindgen::rom_error::rom_error_kErrorXModemEndOfFile,
        XModemCancel = bindgen::rom_error::rom_error_kErrorXModemCancel,
        XModemUnknown = bindgen::rom_error::rom_error_kErrorXModemUnknown,
        XModemProtocol = bindgen::rom_error::rom_error_kErrorXModemProtocol,
        XModemTooManyErrors = bindgen::rom_error::rom_error_kErrorXModemTooManyErrors,
        RomExtInterrupt = bindgen::rom_error::rom_error_kErrorRomExtInterrupt,
        BootLogInvalid = bindgen::rom_error::rom_error_kErrorBootLogInvalid,
        Asn1Internal = bindgen::rom_error::rom_error_kErrorAsn1Internal,
        Asn1StartInvalidArgument = bindgen::rom_error::rom_error_kErrorAsn1StartInvalidArgument,
        Asn1PushBytesInvalidArgument = bindgen::rom_error::rom_error_kErrorAsn1PushBytesInvalidArgument,
        Asn1PushIntegerPadInvalidArgument = bindgen::rom_error::rom_error_kErrorAsn1PushIntegerPadInvalidArgument,
        Asn1PushIntegerInvalidArgument = bindgen::rom_error::rom_error_kErrorAsn1PushIntegerInvalidArgument,
        Asn1FinishBitstringInvalidArgument = bindgen::rom_error::rom_error_kErrorAsn1FinishBitstringInvalidArgument,
        Asn1BufferExhausted = bindgen::rom_error::rom_error_kErrorAsn1BufferExhausted,
        RetRamBadVersion = bindgen::rom_error::rom_error_kErrorRetRamBadVersion,
        RescueReboot = bindgen::rom_error::rom_error_kErrorRescueReboot,
        RescueBadMode = bindgen::rom_error::rom_error_kErrorRescueBadMode,
        RescueImageTooBig = bindgen::rom_error::rom_error_kErrorRescueImageTooBig,
        DiceInvalidKeyType = bindgen::rom_error::rom_error_kErrorDiceInvalidKeyType,
        CertInternal = bindgen::rom_error::rom_error_kErrorCertInternal,
        CertInvalidArgument = bindgen::rom_error::rom_error_kErrorCertInvalidArgument,
        OwnershipInvalidNonce = bindgen::rom_error::rom_error_kErrorOwnershipInvalidNonce,
        OwnershipInvalidMode = bindgen::rom_error::rom_error_kErrorOwnershipInvalidMode,
        OwnershipInvalidSignature = bindgen::rom_error::rom_error_kErrorOwnershipInvalidSignature,
        OwnershipInvalidState = bindgen::rom_error::rom_error_kErrorOwnershipInvalidState,
        OwnershipInvalidRequest = bindgen::rom_error::rom_error_kErrorOwnershipInvalidRequest,
        OwnershipInvalidTag = bindgen::rom_error::rom_error_kErrorOwnershipInvalidTag,
        OwnershipInvalidTagLength = bindgen::rom_error::rom_error_kErrorOwnershipInvalidTagLength,
        OwnershipDuplicateItem = bindgen::rom_error::rom_error_kErrorOwnershipDuplicateItem,
        OwnershipFlashConfigLenth = bindgen::rom_error::rom_error_kErrorOwnershipFlashConfigLenth,
        OwnershipInvalidInfoPage = bindgen::rom_error::rom_error_kErrorOwnershipInvalidInfoPage,
        OwnershipBadInfoPage = bindgen::rom_error::rom_error_kErrorOwnershipBadInfoPage,
        OwnershipNoOwner = bindgen::rom_error::rom_error_kErrorOwnershipNoOwner,
        OwnershipKeyNotFound = bindgen::rom_error::rom_error_kErrorOwnershipKeyNotFound,

    }
}

impl Error for RomError {}

impl From<RomError> for Result<(), RomError> {
    fn from(error: RomError) -> Self {
        if error == RomError::Ok {
            Ok(())
        } else {
            Err(error)
        }
    }
}

impl From<RomError> for Result<(), anyhow::Error> {
    fn from(error: RomError) -> Self {
        if error == RomError::Ok {
            Ok(())
        } else {
            Err(error.into())
        }
    }
}