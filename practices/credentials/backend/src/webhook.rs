//! Sending webhook calls.
//!
//! The notifier POSTs through a [`WebhookTransport`], so it runs against a
//! real HTTP client in production and against [`HermeticTransport`] in tests
//! and local runs.

use std::collections::HashMap;
use std::future::Future;
use std::pin::Pin;
use std::sync::Mutex;
use std::time::Duration;

use thiserror::Error;
use url::Url;

use crate::notifier::CANARY_URL;

#[derive(Debug, Clone, Error, PartialEq, Eq)]
pub enum WebhookError {
    #[error("invalid webhook URL {0}")]
    InvalidUrl(String),
    #[error("{0} is unreachable")]
    Unreachable(String),
}

/// The response to one POST: an HTTP status code, or why there was none.
pub type PostFuture<'a> = Pin<Box<dyn Future<Output = Result<u16, WebhookError>> + Send + 'a>>;

/// Something that can POST a JSON body to a webhook URL.
pub trait WebhookTransport: Send + Sync {
    fn post<'a>(&'a self, url: &'a str, body: &'a [u8]) -> PostFuture<'a>;
}

/// How an in-process endpoint answers.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Endpoint {
    /// Answers `status` after `after`.
    Respond { status: u16, after: Duration },
    /// Accepts the connection and never answers.
    Hang,
}

impl Endpoint {
    /// Round trip of a healthy relying-party endpoint.
    pub const TYPICAL_LATENCY: Duration = Duration::from_millis(150);

    pub fn ok() -> Self {
        Endpoint::Respond { status: 200, after: Self::TYPICAL_LATENCY }
    }

    pub fn status(status: u16) -> Self {
        Endpoint::Respond { status, after: Self::TYPICAL_LATENCY }
    }

    pub fn slow(after: Duration) -> Self {
        Endpoint::Respond { status: 200, after }
    }
}

/// Answers every call in-process; nothing leaves the machine. Endpoints are
/// registered per URL (or per host); anything unregistered is unreachable.
/// The canary's host is answered by a local stub that acknowledges every
/// call.
#[derive(Debug)]
pub struct HermeticTransport {
    routes: Mutex<HashMap<String, Endpoint>>,
    hosts: Mutex<HashMap<String, Endpoint>>,
    received: Mutex<HashMap<String, Vec<Vec<u8>>>>,
}

impl Default for HermeticTransport {
    fn default() -> Self {
        HermeticTransport::new()
    }
}

impl HermeticTransport {
    pub fn new() -> Self {
        let transport = HermeticTransport {
            routes: Mutex::new(HashMap::new()),
            hosts: Mutex::new(HashMap::new()),
            received: Mutex::new(HashMap::new()),
        };
        let canary_host = Url::parse(CANARY_URL).ok().and_then(|u| u.host_str().map(str::to_string));
        if let Some(host) = canary_host {
            transport.route_host(&host, Endpoint::Respond { status: 200, after: Duration::ZERO });
        }
        transport
    }

    /// Answers calls to exactly `url` as `endpoint`.
    pub fn route(&self, url: &str, endpoint: Endpoint) {
        self.routes.lock().unwrap().insert(url.to_string(), endpoint);
    }

    /// Answers calls to any URL on `host` as `endpoint`.
    pub fn route_host(&self, host: &str, endpoint: Endpoint) {
        self.hosts.lock().unwrap().insert(host.to_string(), endpoint);
    }

    /// The bodies `url` has answered, in the order they arrived.
    pub fn received(&self, url: &str) -> Vec<Vec<u8>> {
        self.received.lock().unwrap().get(url).cloned().unwrap_or_default()
    }

    fn endpoint_for(&self, url: &str) -> Result<Endpoint, WebhookError> {
        if let Some(endpoint) = self.routes.lock().unwrap().get(url) {
            return Ok(*endpoint);
        }
        let parsed = Url::parse(url).map_err(|_| WebhookError::InvalidUrl(url.to_string()))?;
        let host = parsed.host_str().ok_or_else(|| WebhookError::InvalidUrl(url.to_string()))?;
        self.hosts.lock().unwrap().get(host).copied().ok_or_else(|| WebhookError::Unreachable(url.to_string()))
    }
}

impl WebhookTransport for HermeticTransport {
    fn post<'a>(&'a self, url: &'a str, body: &'a [u8]) -> PostFuture<'a> {
        Box::pin(async move {
            match self.endpoint_for(url)? {
                Endpoint::Hang => std::future::pending().await,
                Endpoint::Respond { status, after } => {
                    tokio::time::sleep(after).await;
                    self.received.lock().unwrap().entry(url.to_string()).or_default().push(body.to_vec());
                    Ok(status)
                }
            }
        })
    }
}
