// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use acorn::{GenerateFlags, KeyEntry, KeyInfo, SpxInterface};
use anyhow::{anyhow, Result};
use sphincsplus::{DecodeKey, EncodeKey};
use sphincsplus::{SphincsPlus, SpxDomain, SpxError, SpxPublicKey, SpxSecretKey};
use zeroize::Zeroizing;
use std::process::Command;
use serde::Deserialize;

use reqwest::Url;
use reqwest::blocking::Client;

use crate::error::HsmError;
use crate::util::attribute::{AttrData, AttributeMap, AttributeType};

/// SpxEf implements SPHINCS+ signing via Google CloudKms.
pub struct SpxKms {
    keyring: Url,
    auth: Zeroizing<String>,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct KmsKeyList {
    crypto_keys: Vec<KmsKeyRef>
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct VersionTemplate {
    protection_level: String,
    algorithm: String,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct KmsKeyRef {
    name: String,
    version_template: VersionTemplate,
}

impl SpxKms {
    pub fn new(keyring: &str) -> Result<Box<Self>> {
        let output = Command::new("gcloud")
            .args(["auth", "print-access-token"]).output()?;
        if output.status.success() {
            // Get the authorization token and strip trailing newlines.
            let mut auth = String::from_utf8(output.stdout)?;
            let len = auth.trim_end().len();
            auth.truncate(len);
            Ok(Box::new(Self {
                keyring: Url::parse(keyring)?,
                auth: auth.into(),
            }))
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            Err(anyhow!("gcloud error {:?}: {}", output.status, stderr))
        }
    }
}

impl SpxInterface for SpxKms {
    /// Get the version of the backend.
    fn get_version(&self) -> Result<String> {
        Ok(String::from("CloudKMS SPX preview 0.0.1"))
    }

    /// List keys known to the backend.
    fn list_keys(&self) -> Result<Vec<KeyEntry>> {
        let client = Client::new();
        let keys = self.keyring.join("cryptoKeys")?;
        log::info!("keys = {keys:?}");
        let res = client.get(keys)
            .bearer_auth(&*self.auth)
            .send()?;
        let keys = res.json::<KmsKeyList>()?;
        log::info!("res = {keys:?}");
        Err(HsmError::Unsupported("unimplemented".into()).into())
    }

    /// Get the public key info.
    fn get_key_info(&self, alias: &str) -> Result<KeyInfo> {
        Err(HsmError::Unsupported("unimplemented".into()).into())
    }

    /// Generate a key pair.
    fn generate_key(
        &self,
        alias: &str,
        algorithm: &str,
        _token: &str,
        flags: GenerateFlags,
    ) -> Result<KeyEntry> {
        Err(HsmError::Unsupported("unimplemented".into()).into())
    }

    /// Import a key pair.
    fn import_keypair(
        &self,
        alias: &str,
        algorithm: &str,
        _token: &str,
        overwrite: bool,
        public_key: &[u8],
        private_key: &[u8],
    ) -> Result<KeyEntry> {
        Err(HsmError::Unsupported("unimplemented".into()).into())
    }

    /// Sign a message.
    fn sign(&self, alias: Option<&str>, key_hash: Option<&str>, message: &[u8]) -> Result<Vec<u8>> {
        let alias = alias.ok_or(HsmError::NoSearchCriteria)?;
        if key_hash.is_some() {
            log::warn!("ignored key_hash {key_hash:?}");
        }
        Err(HsmError::Unsupported("unimplemented".into()).into())
    }

    /// Verify a message.
    fn verify(
        &self,
        alias: Option<&str>,
        key_hash: Option<&str>,
        message: &[u8],
        signature: &[u8],
    ) -> Result<bool> {
        let alias = alias.ok_or(HsmError::NoSearchCriteria)?;
        if key_hash.is_some() {
            log::warn!("ignored key_hash {key_hash:?}");
        }
        Err(HsmError::Unsupported("unimplemented".into()).into())
    }
}
