//! Status-change webhooks.
//!
//! When a credential's status flips ([`crate::status::revoke_credential`]),
//! [`Notifier::notify`] sends the change to the relying parties that
//! subscribed to the issuing tenant's changes. A subscription is a tenant
//! setting of kind [`WEBHOOK_KIND`] whose value holds the endpoint `url`.
//!
//! The canary is a platform subscription that receives every change;
//! [`Notifier::canary_healthy`] is the notifier's health check. Every
//! delivery attempt is reported to the [`DeliverySink`].

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde_json::json;

use crate::settings::{Setting, SettingsStore};
use crate::status::StatusChange;
use crate::webhook::WebhookTransport;

/// How long one status change may take to fan out.
pub const DISPATCH_BUDGET: Duration = Duration::from_secs(10);

/// Setting kind of a webhook subscription.
pub const WEBHOOK_KIND: &str = "webhook";

pub const CANARY_ID: &str = "canary";
pub const CANARY_URL: &str = "https://example.com/webhooks/status";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Subscription {
    pub id: String,
    pub url: String,
}

impl Subscription {
    pub fn canary() -> Self {
        Subscription { id: CANARY_ID.to_string(), url: CANARY_URL.to_string() }
    }

    /// The subscription a webhook setting describes; its id is the part of
    /// the key after `webhook/`.
    pub fn from_setting(setting: &Setting) -> Option<Self> {
        let url = setting.value.get("url")?.as_str()?;
        let id = setting.key.strip_prefix("webhook/").unwrap_or(&setting.key);
        Some(Subscription { id: id.to_string(), url: url.to_string() })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outcome {
    /// The endpoint acknowledged the call (2xx).
    Delivered { status: u16 },
    /// The endpoint refused the call or could not be reached.
    Failed { reason: String },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeliveryEvent {
    pub tenant: String,
    pub subscription: String,
    pub outcome: Outcome,
}

/// Where delivery outcomes go (metrics, audit).
pub trait DeliverySink: Send + Sync {
    fn record(&self, event: DeliveryEvent);
}

/// Keeps every event in memory.
#[derive(Debug, Default)]
pub struct MemorySink {
    events: Mutex<Vec<DeliveryEvent>>,
}

impl MemorySink {
    pub fn events(&self) -> Vec<DeliveryEvent> {
        self.events.lock().unwrap().clone()
    }
}

impl DeliverySink for MemorySink {
    fn record(&self, event: DeliveryEvent) {
        self.events.lock().unwrap().push(event);
    }
}

/// The JSON body sent for `change`.
pub fn payload(change: &StatusChange) -> Vec<u8> {
    json!({
        "type": "credential.status_changed",
        "credential_id": change.credential_id,
        "issuer": change.issuer,
        "status_list": change.status_list,
        "status_index": change.status_index,
        "revoked": change.revoked,
    })
    .to_string()
    .into_bytes()
}

pub struct Notifier {
    settings: Arc<SettingsStore>,
    transport: Arc<dyn WebhookTransport>,
    sink: Arc<dyn DeliverySink>,
    /// Subscribers to every tenant's changes.
    platform: Vec<Subscription>,
    canary_ok: AtomicBool,
}

impl Notifier {
    pub fn new(settings: Arc<SettingsStore>, transport: Arc<dyn WebhookTransport>, sink: Arc<dyn DeliverySink>) -> Self {
        Notifier {
            settings,
            transport,
            sink,
            platform: vec![Subscription::canary()],
            canary_ok: AtomicBool::new(false),
        }
    }

    /// Adds a subscriber to every tenant's changes.
    pub fn with_platform_subscriber(mut self, subscription: Subscription) -> Self {
        self.platform.push(subscription);
        self
    }

    /// Whether the canary acknowledged the most recent change.
    pub fn canary_healthy(&self) -> bool {
        self.canary_ok.load(Ordering::SeqCst)
    }

    /// Sends `change` to the platform subscribers and to every subscriber of
    /// the issuing tenant.
    pub async fn notify(&self, change: &StatusChange) {
        let tenant = change.issuer.as_str();
        let body = payload(change);

        let fan_out = async {
            for sub in &self.platform {
                let delivered = self.dispatch(tenant, sub, &body).await;
                if sub.id == CANARY_ID {
                    self.canary_ok.store(delivered, Ordering::SeqCst);
                }
            }
            for sub in self.subscriptions(tenant).await {
                self.dispatch(tenant, &sub, &body).await;
            }
        };

        if tokio::time::timeout(DISPATCH_BUDGET, fan_out).await.is_err() {
            eprintln!("notifier: {tenant}: fan-out for {} did not finish within {DISPATCH_BUDGET:?}", change.credential_id);
        }
    }

    /// The tenant's webhook subscriptions.
    async fn subscriptions(&self, tenant: &str) -> Vec<Subscription> {
        let mut subscriptions = Vec::new();
        let mut cursor: Option<String> = None;
        loop {
            let page = self.settings.query(tenant, cursor.as_deref()).await;
            subscriptions.extend(page.items.iter().filter(|s| s.kind == WEBHOOK_KIND).filter_map(Subscription::from_setting));
            match page.next {
                Some(next) => cursor = Some(next),
                None => return subscriptions,
            }
        }
    }

    /// POSTs `body` to `sub` and reports the outcome; `true` if delivered.
    async fn dispatch(&self, tenant: &str, sub: &Subscription, body: &[u8]) -> bool {
        let outcome = match self.transport.post(&sub.url, body).await {
            Ok(status) if (200..300).contains(&status) => Outcome::Delivered { status },
            Ok(status) => Outcome::Failed { reason: format!("HTTP {status}") },
            Err(error) => Outcome::Failed { reason: error.to_string() },
        };
        let delivered = matches!(outcome, Outcome::Delivered { .. });
        self.sink.record(DeliveryEvent { tenant: tenant.to_string(), subscription: sub.id.clone(), outcome });
        delivered
    }
}
