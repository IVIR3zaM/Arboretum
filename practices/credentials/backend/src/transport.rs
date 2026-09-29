//! Fetching hosted DID documents.
//!
//! Issuer `did.json` documents are published to the document bucket behind
//! the issuers' domains (see `reference/infra/hosted-dids/`). The service
//! reads them through a [`DocumentTransport`], so the same resolver runs
//! against the bucket mirror in development and against fixtures in tests.

use std::collections::HashMap;
use std::path::{Component, Path, PathBuf};

use thiserror::Error;
use url::Url;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum TransportError {
    #[error("invalid document URL {0}")]
    InvalidUrl(String),
    #[error("no document at {0}")]
    NotFound(String),
    #[error("reading {url}: {reason}")]
    Io { url: String, reason: String },
}

/// Something that can GET a document by its HTTPS URL.
pub trait DocumentTransport: Send + Sync {
    fn get(&self, url: &str) -> Result<Vec<u8>, TransportError>;
}

/// Serves `https://<authority>/<path>` from `<root>/<authority>/<path>`: a
/// local mirror of the document bucket, laid out the way the bucket keys
/// its objects.
#[derive(Debug, Clone)]
pub struct MirrorTransport {
    root: PathBuf,
}

impl MirrorTransport {
    pub fn new(root: impl AsRef<Path>) -> Self {
        MirrorTransport { root: root.as_ref().to_path_buf() }
    }

    /// The mirror at `$DID_MIRROR_ROOT`, or the checked-in copy of the bucket.
    pub fn from_env() -> Self {
        match std::env::var_os("DID_MIRROR_ROOT") {
            Some(root) => MirrorTransport::new(root),
            None => MirrorTransport::new(Path::new(env!("CARGO_MANIFEST_DIR")).join("../reference/infra/hosted-dids")),
        }
    }

    fn path_for(&self, url: &str) -> Result<PathBuf, TransportError> {
        let invalid = || TransportError::InvalidUrl(url.to_string());
        let parsed = Url::parse(url).map_err(|_| invalid())?;
        if parsed.scheme() != "https" || url.contains("/../") {
            return Err(invalid());
        }
        let host = parsed.host_str().ok_or_else(invalid)?;
        let authority = match parsed.port() {
            Some(port) => format!("{host}:{port}"),
            None => host.to_string(),
        };
        let mut path = self.root.join(authority);
        for segment in parsed.path_segments().into_iter().flatten() {
            let segment = Path::new(segment);
            if segment.components().any(|c| !matches!(c, Component::Normal(_))) {
                return Err(invalid());
            }
            path.push(segment);
        }
        Ok(path)
    }
}

impl DocumentTransport for MirrorTransport {
    fn get(&self, url: &str) -> Result<Vec<u8>, TransportError> {
        let path = self.path_for(url)?;
        std::fs::read(&path).map_err(|e| match e.kind() {
            std::io::ErrorKind::NotFound => TransportError::NotFound(url.to_string()),
            _ => TransportError::Io { url: url.to_string(), reason: e.to_string() },
        })
    }
}

/// An in-memory set of documents keyed by URL.
#[derive(Debug, Clone, Default)]
pub struct StaticTransport {
    documents: HashMap<String, Vec<u8>>,
}

impl StaticTransport {
    pub fn with(mut self, url: &str, body: impl Into<Vec<u8>>) -> Self {
        self.documents.insert(url.to_string(), body.into());
        self
    }
}

impl DocumentTransport for StaticTransport {
    fn get(&self, url: &str) -> Result<Vec<u8>, TransportError> {
        self.documents.get(url).cloned().ok_or_else(|| TransportError::NotFound(url.to_string()))
    }
}
