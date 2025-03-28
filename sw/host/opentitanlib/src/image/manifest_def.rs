// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use crate::image::manifest::*;
use crate::image::manifest_ext::ManifestExtId;
use crate::util::bigint::fixed_size_bigint;
use crate::util::num_de::HexEncoded;
use crate::util::parse_int::ParseInt;

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};
use std::convert::{TryFrom, TryInto};
use std::fmt;
use std::iter::IntoIterator;
use std::path::Path;
use thiserror::Error;

use zerocopy::IntoBytes;

#[derive(Debug, Error)]
pub enum ManifestError {
    #[error("Manifest is missing field \"{0}\".")]
    MissingField(&'static str),
}

fixed_size_bigint!(ManifestSigverifyBuffer, at_most 3072);

#[derive(Clone, Default, Debug, Deserialize, Serialize)]
struct ManifestSigverifyBigInt(Option<HexEncoded<ManifestSigverifyBuffer>>);

#[derive(Clone, Default, Debug, Deserialize, Serialize)]
struct ManifestSmallInt<T: ParseInt + fmt::LowerHex>(Option<HexEncoded<T>>);

impl fmt::LowerHex for ManifestSigverifyBuffer {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> Result<(), fmt::Error> {
        fmt::LowerHex::fmt(&self.as_biguint(), f)
    }
}

/// A macro for wrapping manifest struct definitions that parse from HJSON.
///
/// The #[repr(C)] version of `Manifest` can only be built when the fields in `ManifestSpec` are
/// present. This macro sets up the field by field conversion and provides the field names for
/// purposes of error reporting.
macro_rules! manifest_def {
    ($access:vis struct $name:ident {
        $(
            $(#[$doc:meta])?
            $field_name:ident: $field_type:ty,
        )*
    }, $out_type:ident) => {
        #[derive(Clone, Default, Deserialize, Serialize, Debug)]
        $access struct $name {
            $(
                $(#[$doc])?
                #[serde(default)]
                $field_name: $field_type,
            )*
        }

        impl ManifestPacked<$out_type> for $name {
            fn unpack(self, _name: &'static str) -> Result<$out_type> {
                Ok($out_type {
                    // Call `unpack()` on each field with the field's name included for use in
                    // error messages.
                    $($field_name: self.$field_name
                        .unpack(stringify!($field_name))?.try_into()?,)*
                })
            }

            fn overwrite(&mut self, o: $name) {
                $(self.$field_name.overwrite(o.$field_name);)*
            }
        }

        impl TryInto<$out_type> for $name {
            type Error = anyhow::Error;

            fn try_into(self) -> Result<$out_type> {
                self.unpack("")
            }
        }

        impl TryFrom<&$out_type> for $name {
            type Error = anyhow::Error;

            fn try_from(o: &$out_type) -> Result<Self> {
                Ok($name {
                    $($field_name: (&o.$field_name).try_into()?,)*
                })
            }
        }
    }
}

impl ManifestSpec {
    pub fn read_from_file(path: &Path) -> Result<ManifestSpec> {
        Ok(deser_hjson::from_str(
            &std::fs::read_to_string(path).with_context(|| format!("Failed to open {path:?}"))?,
        )?)
    }

    pub fn overwrite_fields(&mut self, other: ManifestSpec) {
        self.overwrite(other)
    }

    pub fn update_signature(&mut self, signature: ManifestSigverifyBuffer) {
        self.signature.0 = Some(HexEncoded(signature))
    }

    pub fn update_pub_key(&mut self, pub_key: ManifestSigverifyBuffer) {
        self.pub_key.0 = Some(HexEncoded(pub_key))
    }

    pub fn signature(&self) -> Option<&ManifestSigverifyBuffer> {
        self.signature.0.as_ref().map(|v| &v.0)
    }

    pub fn pub_key(&self) -> Option<&ManifestSigverifyBuffer> {
        self.pub_key.0.as_ref().map(|v| &v.0)
    }

    pub fn has_length(&self) -> bool {
        self.length.0.is_some()
    }
}

trait ManifestPacked<T> {
    /// The default error for missing fields.
    fn unpack_err(&self, name: &'static str) -> Result<T> {
        bail!(ManifestError::MissingField(name))
    }

    /// Unpack optional fields in the manifest, and error if the field isn't defined.
    fn unpack(self, name: &'static str) -> Result<T>;

    /// Overwrite manifest field.
    fn overwrite(&mut self, o: Self);
}

impl ManifestPacked<ManifestSigverifyBuffer> for ManifestSigverifyBigInt {
    fn unpack(self, name: &'static str) -> Result<ManifestSigverifyBuffer> {
        match self.0 {
            Some(v) => Ok(v.0),
            None => self.unpack_err(name),
        }
    }

    fn overwrite(&mut self, o: Self) {
        if o.0.is_some() {
            *self = o;
        }
    }
}

impl ManifestPacked<[ManifestExtTableEntry; CHIP_MANIFEST_EXT_TABLE_COUNT]>
    for [ManifestExtTableEntryDef; CHIP_MANIFEST_EXT_TABLE_COUNT]
{
    fn unpack(
        self,
        _name: &'static str,
    ) -> Result<[ManifestExtTableEntry; CHIP_MANIFEST_EXT_TABLE_COUNT]> {
        Ok(self.map(|v| match v.0 {
            ManifestExtEntryVar::Name(name) => ManifestExtTableEntry {
                identifier: name.into(),
                offset: 0,
            },
            ManifestExtEntryVar::IdOffset { identifier, offset } => ManifestExtTableEntry {
                identifier: identifier.into(),
                offset,
            },
            _ => ManifestExtTableEntry {
                identifier: 0,
                offset: 0,
            },
        }))
    }

    fn overwrite(&mut self, o: Self) {
        for i in 0..self.len() {
            match o[i].0 {
                ManifestExtEntryVar::Name(other_id) => match self[i].0 {
                    ManifestExtEntryVar::IdOffset {
                        identifier: self_id,
                        offset: _,
                    } => {
                        if self_id == other_id {
                            // Do not overwrite existing entries with matching IDs.
                            continue;
                        } else {
                            self[i].0 = o[i].0.clone()
                        }
                    }
                    _ => self[i].0 = o[i].0.clone(),
                },
                ManifestExtEntryVar::None => (),
                _ => self[i].0 = o[i].0.clone(),
            }
        }
    }
}

impl<T: ParseInt + fmt::LowerHex> ManifestPacked<T> for ManifestSmallInt<T> {
    fn unpack(self, name: &'static str) -> Result<T> {
        match self.0 {
            Some(v) => Ok(v.0),
            None => self.unpack_err(name),
        }
    }

    fn overwrite(&mut self, o: Self) {
        if o.0.is_some() {
            *self = o;
        }
    }
}

impl<T: ParseInt + fmt::LowerHex, const N: usize> ManifestPacked<[T; N]>
    for [ManifestSmallInt<T>; N]
{
    fn unpack(self, name: &'static str) -> Result<[T; N]> {
        let results = self.map(|e| e.unpack(name));
        if let Some(err_idx) = results.iter().position(Result::is_err) {
            IntoIterator::into_iter(results).nth(err_idx).unwrap()?;
            unreachable!();
        } else {
            Ok(results.map(|x| x.unwrap()))
        }
    }

    fn overwrite(&mut self, o: Self) {
        // Only perform the overwrite if all elements of `o` are present.
        if o.iter().all(|v| v.0.is_some()) {
            *self = o;
        }
    }
}

manifest_def! {
    pub struct ManifestSpec {
        signature: ManifestSigverifyBigInt,
        usage_constraints: ManifestUsageConstraintsDef,
        pub_key: ManifestSigverifyBigInt,
        address_translation: ManifestSmallInt<u32>,
        identifier: ManifestSmallInt<u32>,
        manifest_version: ManifestVersionDef,
        signed_region_end: ManifestSmallInt<u32>,
        length: ManifestSmallInt<u32>,
        version_major: ManifestSmallInt<u32>,
        version_minor: ManifestSmallInt<u32>,
        security_version: ManifestSmallInt<u32>,
        timestamp: [ManifestSmallInt<u32>; 2],
        binding_value: [ManifestSmallInt<u32>; 8],
        max_key_version: ManifestSmallInt<u32>,
        code_start: ManifestSmallInt<u32>,
        code_end: ManifestSmallInt<u32>,
        entry_point: ManifestSmallInt<u32>,
        extensions: [ManifestExtTableEntryDef; CHIP_MANIFEST_EXT_TABLE_COUNT],
    }, Manifest
}

manifest_def! {
    pub struct ManifestUsageConstraintsDef {
        selector_bits: ManifestSmallInt<u32>,
        device_id: [ManifestSmallInt<u32>; 8],
        manuf_state_creator: ManifestSmallInt<u32>,
        manuf_state_owner: ManifestSmallInt<u32>,
        life_cycle_state: ManifestSmallInt<u32>,
    }, ManifestUsageConstraints
}

manifest_def! {
    pub struct ManifestVersionDef {
        minor: ManifestSmallInt<u16>,
        major: ManifestSmallInt<u16>,
    }, ManifestVersion
}

#[derive(Clone, Default, Deserialize, Serialize, Debug)]
#[serde(untagged)]
enum ManifestExtEntryVar {
    #[default]
    None,
    Name(ManifestExtId),
    IdOffset {
        identifier: ManifestExtId,
        offset: u32,
    },
}

#[derive(Clone, Default, Deserialize, Serialize, Debug)]
pub struct ManifestExtTableEntryDef(ManifestExtEntryVar);

impl TryFrom<ManifestSigverifyBuffer> for SigverifyBuffer {
    type Error = anyhow::Error;

    fn try_from(buffer: ManifestSigverifyBuffer) -> Result<SigverifyBuffer> {
        if buffer.eq(&ManifestSigverifyBuffer::from_le_bytes([0])?) {
            // In the case where the BigInt fields are defined but == 0 we should just keep it 0.
            // Without this the conversion to [u32; 96] would fail.
            Ok(SigverifyBuffer {
                data: le_slice_to_arr(&[0]),
            })
        } else {
            // Convert between the BigInt byte representation and the manifest word representation.
            Ok(SigverifyBuffer {
                data: le_bytes_to_word_arr(&buffer.to_le_bytes())?,
            })
        }
    }
}

pub(crate) fn le_bytes_to_word_arr<const N: usize>(bytes: &[u8]) -> Result<[u32; N]> {
    Ok(le_slice_to_arr(
        bytes
            .chunks(4)
            .map(|v| Ok(u32::from_le_bytes(le_slice_to_arr(v))))
            .collect::<Result<Vec<u32>>>()?
            .as_slice(),
    ))
}

/// Takes a slice with LE element ordering and pads the MSBs with 0 to produce a fixed length array
///
/// This is similar to using `try_into()` but does not have the requirement that the slice has
/// exactly the correct length.
fn le_slice_to_arr<T: Default + Copy, const N: usize>(slice: &[T]) -> [T; N] {
    let mut arr = [T::default(); N];
    arr[..slice.len()].copy_from_slice(slice);
    arr
}

impl TryFrom<[u32; 96]> for SigverifyBuffer {
    type Error = anyhow::Error;

    fn try_from(words: [u32; 96]) -> Result<SigverifyBuffer> {
        Ok(SigverifyBuffer { data: words })
    }
}

impl TryFrom<[u32; 8]> for KeymgrBindingValue {
    type Error = anyhow::Error;

    fn try_from(words: [u32; 8]) -> Result<KeymgrBindingValue> {
        Ok(KeymgrBindingValue { data: words })
    }
}

impl TryFrom<[u32; 2]> for Timestamp {
    type Error = anyhow::Error;

    fn try_from(words: [u32; 2]) -> Result<Timestamp> {
        Ok(Timestamp {
            timestamp_low: words[0],
            timestamp_high: words[1],
        })
    }
}

impl TryFrom<[u32; 8]> for LifecycleDeviceId {
    type Error = anyhow::Error;

    fn try_from(words: [u32; 8]) -> Result<LifecycleDeviceId> {
        Ok(LifecycleDeviceId { device_id: words })
    }
}

impl TryFrom<SigverifyBuffer> for ManifestSigverifyBigInt {
    type Error = anyhow::Error;

    fn try_from(o: SigverifyBuffer) -> Result<ManifestSigverifyBigInt> {
        (&o).try_into()
    }
}

impl TryFrom<&SigverifyBuffer> for ManifestSigverifyBigInt {
    type Error = anyhow::Error;

    fn try_from(o: &SigverifyBuffer) -> Result<ManifestSigverifyBigInt> {
        let rsa = ManifestSigverifyBuffer::from_le_bytes(o.data.as_bytes())?;
        Ok(ManifestSigverifyBigInt(Some(HexEncoded(rsa))))
    }
}

impl<T> From<&T> for ManifestSmallInt<T>
where
    T: ParseInt + fmt::LowerHex + Copy,
{
    fn from(o: &T) -> ManifestSmallInt<T> {
        ManifestSmallInt(Some(HexEncoded(*o)))
    }
}

impl From<&KeymgrBindingValue> for [ManifestSmallInt<u32>; 8] {
    fn from(o: &KeymgrBindingValue) -> [ManifestSmallInt<u32>; 8] {
        o.data.map(|v| ManifestSmallInt(Some(HexEncoded(v))))
    }
}
impl From<&Timestamp> for [ManifestSmallInt<u32>; 2] {
    fn from(o: &Timestamp) -> [ManifestSmallInt<u32>; 2] {
        [
            ManifestSmallInt(Some(HexEncoded(o.timestamp_low))),
            ManifestSmallInt(Some(HexEncoded(o.timestamp_high))),
        ]
    }
}

impl From<&LifecycleDeviceId> for [ManifestSmallInt<u32>; 8] {
    fn from(o: &LifecycleDeviceId) -> [ManifestSmallInt<u32>; 8] {
        o.device_id.map(|v| ManifestSmallInt(Some(HexEncoded(v))))
    }
}

impl From<&ManifestExtTableEntry> for ManifestExtTableEntryDef {
    fn from(o: &ManifestExtTableEntry) -> ManifestExtTableEntryDef {
        ManifestExtTableEntryDef(ManifestExtEntryVar::IdOffset {
            identifier: ManifestExtId(o.identifier),
            offset: o.offset,
        })
    }
}

impl From<[ManifestExtTableEntry; CHIP_MANIFEST_EXT_TABLE_COUNT]> for ManifestExtTable {
    fn from(o: [ManifestExtTableEntry; CHIP_MANIFEST_EXT_TABLE_COUNT]) -> ManifestExtTable {
        ManifestExtTable { entries: o }
    }
}

impl From<&ManifestExtTable> for [ManifestExtTableEntryDef; CHIP_MANIFEST_EXT_TABLE_COUNT] {
    fn from(o: &ManifestExtTable) -> [ManifestExtTableEntryDef; CHIP_MANIFEST_EXT_TABLE_COUNT] {
        o.entries.map(|v| (&v).into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::testdata;
    use deser_hjson::from_str;

    #[test]
    fn test_manifest_from_hjson() {
        let def: ManifestSpec =
            from_str(&std::fs::read_to_string(testdata("image/manifest.hjson")).unwrap()).unwrap();

        let _: Manifest = def.try_into().unwrap();
    }

    #[test]
    fn test_manifest_from_hjson_missing() {
        let def: ManifestSpec =
            from_str(&std::fs::read_to_string(testdata("image/manifest_missing.hjson")).unwrap())
                .unwrap();

        let res: Result<Manifest> = def.try_into();
        assert!(res.is_err())
    }

    #[test]
    fn test_manifest_overwrite() {
        let mut base: ManifestSpec =
            from_str(&std::fs::read_to_string(testdata("image/manifest.hjson")).unwrap()).unwrap();
        let other = ManifestSpec {
            identifier: from_str("0xabcd").unwrap(),
            binding_value: from_str(stringify!(["0", "1", "2", "3", "4", "5", "6", "7"])).unwrap(),
            ..Default::default()
        };
        base.overwrite(other);
        assert_eq!(base.identifier.0.unwrap().0, 0xabcd);
        assert_eq!(
            base.binding_value.map(|v| v.0.unwrap().0)[..],
            [0, 1, 2, 3, 4, 5, 6, 7]
        );

        // Ensure unspecified fields are not overwritten.
        assert_eq!(base.address_translation.0.unwrap().0, 0x739);
    }

    #[test]
    fn test_manifest_convert() {
        let def1: ManifestSpec =
            from_str(&std::fs::read_to_string(testdata("image/manifest.hjson")).unwrap()).unwrap();
        let def2 = def1.clone();

        let bin1: Manifest = def1.try_into().unwrap();
        let bin2: Manifest = def2.try_into().unwrap();

        let redef: ManifestSpec = (&bin1).try_into().unwrap();
        let rebin: Manifest = redef.try_into().unwrap();
        assert_eq!(bin2.as_bytes(), rebin.as_bytes());
    }
}
