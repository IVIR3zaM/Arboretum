use std::sync::Arc;

use credentials_backend::notifier::{DeliveryEvent, MemorySink, Notifier, Outcome, WEBHOOK_KIND};
use credentials_backend::settings::{Setting, SettingsStore};
use credentials_backend::status::StatusChange;
use credentials_backend::webhook::{Endpoint, HermeticTransport};
use serde_json::{json, Value};

const HARBOUR: &str = "did:web:members.harbourclub.example";
const CEDAR: &str = "did:web:issuer.cedarrowing.example";

fn revoked(issuer: &str, index: usize) -> StatusChange {
    StatusChange {
        credential_id: format!("urn:uuid:00000000-0000-4000-8000-{index:012}"),
        issuer: issuer.to_string(),
        status_list: format!("{issuer}#revocation"),
        status_index: index,
        revoked: true,
    }
}

fn subscribe(settings: &SettingsStore, tenant: &str, id: &str, url: &str) {
    settings.put(Setting::new(tenant, &format!("webhook/{id}"), WEBHOOK_KIND, json!({ "url": url })));
}

/// A tenant as most clubs look: a handful of preferences and a few relying
/// parties listening for status changes.
fn small_tenant(settings: &SettingsStore, transport: &HermeticTransport, tenant: &str, host: &str) -> Vec<String> {
    for i in 0..12 {
        settings.put(Setting::new(tenant, &format!("pref/{i:02}"), "preference", json!({ "n": i })));
    }
    (1..=3)
        .map(|i| {
            let url = format!("https://{host}/hooks/{i}");
            subscribe(settings, tenant, &format!("rp-{i}"), &url);
            transport.route(&url, Endpoint::ok());
            url
        })
        .collect()
}

struct Rig {
    settings: Arc<SettingsStore>,
    transport: Arc<HermeticTransport>,
    sink: Arc<MemorySink>,
    notifier: Notifier,
}

fn rig() -> Rig {
    let settings = Arc::new(SettingsStore::new());
    let transport = Arc::new(HermeticTransport::new());
    let sink = Arc::new(MemorySink::default());
    let notifier = Notifier::new(settings.clone(), transport.clone(), sink.clone());
    Rig { settings, transport, sink, notifier }
}

#[tokio::test(start_paused = true)]
async fn every_subscriber_of_the_tenant_is_notified_once() {
    let rig = rig();
    let urls = small_tenant(&rig.settings, &rig.transport, HARBOUR, "door.harbourclub.example");

    rig.notifier.notify(&revoked(HARBOUR, 7)).await;

    for url in &urls {
        assert_eq!(rig.transport.received(url).len(), 1, "{url}");
    }
}

#[tokio::test(start_paused = true)]
async fn the_notification_carries_the_status_change() {
    let rig = rig();
    let urls = small_tenant(&rig.settings, &rig.transport, HARBOUR, "door.harbourclub.example");
    let change = revoked(HARBOUR, 7);

    rig.notifier.notify(&change).await;

    let body: Value = serde_json::from_slice(&rig.transport.received(&urls[0])[0]).unwrap();
    assert_eq!(body["type"], "credential.status_changed");
    assert_eq!(body["credential_id"], change.credential_id.as_str());
    assert_eq!(body["issuer"], HARBOUR);
    assert_eq!(body["status_list"], change.status_list.as_str());
    assert_eq!(body["status_index"], 7);
    assert_eq!(body["revoked"], true);
}

#[tokio::test(start_paused = true)]
async fn other_tenants_subscribers_are_not_notified() {
    let rig = rig();
    small_tenant(&rig.settings, &rig.transport, HARBOUR, "door.harbourclub.example");
    let cedar = small_tenant(&rig.settings, &rig.transport, CEDAR, "gate.cedarrowing.example");

    rig.notifier.notify(&revoked(HARBOUR, 7)).await;

    assert!(cedar.iter().all(|url| rig.transport.received(url).is_empty()));
}

#[tokio::test(start_paused = true)]
async fn each_delivery_is_reported_to_the_sink() {
    let rig = rig();
    small_tenant(&rig.settings, &rig.transport, HARBOUR, "door.harbourclub.example");

    rig.notifier.notify(&revoked(HARBOUR, 7)).await;

    let delivered: Vec<String> = rig
        .sink
        .events()
        .into_iter()
        .filter(|e| e.tenant == HARBOUR && matches!(e.outcome, Outcome::Delivered { status: 200 }))
        .map(|e| e.subscription)
        .collect();
    for id in ["rp-1", "rp-2", "rp-3"] {
        assert!(delivered.iter().any(|d| d == id), "{id} not reported: {delivered:?}");
    }
}

#[tokio::test(start_paused = true)]
async fn a_rejected_delivery_is_reported_as_failed() {
    let rig = rig();
    subscribe(&rig.settings, HARBOUR, "rp-down", "https://down.harbourclub.example/hooks");
    rig.transport.route("https://down.harbourclub.example/hooks", Endpoint::status(503));

    rig.notifier.notify(&revoked(HARBOUR, 7)).await;

    let events: Vec<DeliveryEvent> = rig.sink.events().into_iter().filter(|e| e.subscription == "rp-down").collect();
    assert_eq!(events.len(), 1);
    assert!(matches!(&events[0].outcome, Outcome::Failed { .. }));
}

#[tokio::test(start_paused = true)]
async fn the_canary_reports_healthy_once_changes_are_flowing() {
    let rig = rig();
    small_tenant(&rig.settings, &rig.transport, HARBOUR, "door.harbourclub.example");
    assert!(!rig.notifier.canary_healthy());

    rig.notifier.notify(&revoked(HARBOUR, 7)).await;

    assert!(rig.notifier.canary_healthy());
}
