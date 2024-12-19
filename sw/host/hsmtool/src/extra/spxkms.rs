// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use acorn::{GenerateFlags, KeyEntry, KeyInfo, SpxInterface};
use anyhow::{anyhow, Context, Result};
use base64ct::{Base64, Encoding};
use indexmap::IndexMap;
use serde::{de::DeserializeOwned, Deserialize, Serialize};
use serde_json::Value;
use sphincsplus::{DecodeKey, EncodeKey};
use sphincsplus::{SphincsPlus, SpxDomain, SpxError, SpxPublicKey, SpxSecretKey};
use std::process::Command;
use thiserror::Error;
use zeroize::Zeroizing;

use reqwest::blocking::Client;
use reqwest::{IntoUrl, Url};

use crate::error::HsmError;
use crate::util::attribute::{AttrData, AttributeMap, AttributeType};

/// SpxEf implements SPHINCS+ signing via Google CloudKms.
pub struct SpxKms {
    keyring: Url,
    auth: Zeroizing<String>,
}

/// ApiError represents an error result from the cloud API.
#[derive(Deserialize, Debug, Error)]
#[error("api error: code={code} message={message:?}; details={details:?}")]
#[serde(rename_all = "camelCase")]
pub struct ApiError {
    pub code: u32,
    pub message: String,
    pub status: String,
    #[serde(flatten)]
    pub details: IndexMap<String, Value>,
}

// CloudResult assists in deserializing the cloud API return into an error
// or a specific type.
#[derive(Deserialize, Debug)]
enum CloudResult<T> {
    #[serde(rename = "error")]
    Error(ApiError),
    #[serde(untagged)]
    Ok(T),
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
struct KmsKeyList {
    crypto_keys: Vec<KmsKeyRef>,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
struct VersionTemplate {
    protection_level: String,
    algorithm: String,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
struct KmsKeyRef {
    name: String,
    version_template: VersionTemplate,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
struct KmsKeyVersion {
    name: String,
    state: String,
    algorithm: String,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
struct KmsKeyVersions {
    crypto_key_versions: Vec<KmsKeyVersion>,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
struct KmsPublicKey {
    name: String,
    algorithm: String,
    pem: String,
}

#[derive(Serialize, Debug)]
struct KmsDigest {
    sha256: String,
}

#[derive(Serialize, Debug)]
struct KmsSignRequest {
    #[serde(skip_serializing_if = "Option::is_none")]
    digest: Option<KmsDigest>,
    #[serde(skip_serializing_if = "Option::is_none")]
    data: Option<String>,
}

impl SpxKms {
    const ALGORITHM: &'static str = "EC_SIGN_P256_SHA256";
    pub fn new(keyring: &str) -> Result<Box<Self>> {
        let output = Command::new("gcloud")
            .args(["auth", "print-access-token"])
            .output()?;
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

    fn get<RSP: DeserializeOwned>(&self, url: impl IntoUrl) -> Result<RSP> {
        let client = Client::new();
        let resp = client
            .get(url)
            .bearer_auth(&*self.auth)
            .header("content-type", "application/json")
            .send()?;
        match resp.json::<CloudResult<RSP>>()? {
            CloudResult::Error(e) => Err(e.into()),
            CloudResult::Ok(v) => Ok(v),
        }
    }

    fn post<RSP: DeserializeOwned>(&self, url: impl IntoUrl, req: &impl Serialize) -> Result<RSP> {
        let client = Client::new();
        let resp = client.post(url).bearer_auth(&*self.auth).json(req).send()?;
        match resp.json::<CloudResult<RSP>>()? {
            CloudResult::Error(e) => Err(e.into()),
            CloudResult::Ok(v) => Ok(v),
        }
    }

    fn get_key_version(&self, alias: &str) -> Result<KmsKeyVersion> {
        let url = self
            .keyring
            .join(&format!("cryptoKeys/{alias}/cryptoKeyVersions"))?;
        let versions = self.get::<KmsKeyVersions>(url)?;
        match versions
            .crypto_key_versions
            .iter()
            .filter(|v| v.state == "ENABLED" && v.algorithm == Self::ALGORITHM)
            .last()
        {
            Some(key) => Ok(key.clone()),
            None => Err(HsmError::ObjectNotFound(alias.into()).into()),
        }
    }

    fn get_public_key(&self, alias: &str) -> Result<KmsPublicKey> {
        let key = self.get_key_version(alias)?;
        let url = self.keyring.join(&format!("/v1/{}/publicKey", key.name))?;
        self.get(url)
    }
}

impl SpxInterface for SpxKms {
    /// Get the version of the backend.
    fn get_version(&self) -> Result<String> {
        Ok(String::from("CloudKMS 0.0.1"))
    }

    /// List keys known to the backend.
    fn list_keys(&self) -> Result<Vec<KeyEntry>> {
        let keys = self.keyring.join("cryptoKeys")?;
        let keys = self.get::<KmsKeyList>(keys)?;
        let mut result = Vec::new();

        for k in keys.crypto_keys.iter() {
            let (_, name) = k
                .name
                .rsplit_once('/')
                .ok_or_else(|| HsmError::ParseError("could not parse key name".into()))
                .with_context(|| format!("key name {:?}", k.name))?;
            let key = self.get_key_version(name)?;
            result.push(KeyEntry {
                alias: name.into(),
                hash: None,
                algorithm: key.algorithm.clone(),
                ..Default::default()
            });
        }
        Ok(result)
    }

    /// Get the public key info.
    fn get_key_info(&self, alias: &str) -> Result<KeyInfo> {
        let key = self.get_public_key(alias)?;
        Ok(KeyInfo {
            hash: "".into(),
            algorithm: key.algorithm,
            public_key: key.pem.into(),
            private_blob: Vec::new(),
        })
    }

    /// Generate a key pair.
    fn generate_key(
        &self,
        alias: &str,
        algorithm: &str,
        _token: &str,
        flags: GenerateFlags,
    ) -> Result<KeyEntry> {
        Err(HsmError::Unsupported(format!(
            "keygen is not supported by {}",
            self.get_version()?
        ))
        .into())
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
        Err(HsmError::Unsupported(format!(
            "key import is not supported by {}",
            self.get_version()?
        ))
        .into())
    }

    /// Sign a message.
    fn sign(&self, alias: Option<&str>, key_hash: Option<&str>, message: &[u8]) -> Result<Vec<u8>> {
        let alias = alias.ok_or(HsmError::NoSearchCriteria)?;
        if key_hash.is_some() {
            log::warn!("ignored key_hash {key_hash:?}");
        }
        let key = self.get_key_version(alias)?;
        let url = self
            .keyring
            .join(&format!("/v1/{}:asymmetricSign", key.name))?;
        let req = KmsSignRequest {
            digest: None,
            data: Some(Base64::encode_string(message)),
        };
        //let data = IndexMap::<&str, String>::from([ ("data", Base64::encode_string(message)) ]);
        log::info!("req = {req:?}");
        let resp = self.post::<IndexMap<String, String>>(url, &req)?;
        log::info!("resp = {resp:?}");
        let signature = Base64::decode_vec(&resp["signature"])?;
        Ok(signature)
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
