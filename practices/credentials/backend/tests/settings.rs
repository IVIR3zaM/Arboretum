use credentials_backend::settings::{Setting, SettingsStore, PAGE_READ_LATENCY, PAGE_SIZE};
use serde_json::json;
use tokio::time::Instant;

fn store_with(tenant: &str, count: usize) -> SettingsStore {
    let store = SettingsStore::new();
    for i in 0..count {
        store.put(Setting::new(tenant, &format!("pref/{i:05}"), "preference", json!({ "n": i })));
    }
    store
}

#[tokio::test(start_paused = true)]
async fn a_query_returns_the_tenants_settings_a_page_at_a_time() {
    let store = store_with("tenant-a", PAGE_SIZE + 5);
    store.put(Setting::new("tenant-b", "pref/00000", "preference", json!({})));

    let first = store.query("tenant-a", None).await;
    assert_eq!(first.items.len(), PAGE_SIZE);
    assert!(first.items.iter().all(|s| s.tenant == "tenant-a"));
    assert_eq!(first.items[0].key, "pref/00000");

    let second = store.query("tenant-a", first.next.as_deref()).await;
    assert_eq!(second.items.len(), 5);
    assert_eq!(second.next, None);
}

#[tokio::test(start_paused = true)]
async fn a_page_read_takes_the_tables_read_latency() {
    let store = store_with("tenant-a", 3);
    let started = Instant::now();
    store.query("tenant-a", None).await;
    assert_eq!(started.elapsed(), PAGE_READ_LATENCY);
}

#[tokio::test(start_paused = true)]
async fn the_kind_index_returns_only_settings_of_that_kind() {
    let store = store_with("tenant-a", 20);
    store.put(Setting::new("tenant-a", "hook/1", "webhook", json!({ "url": "https://rp.example/1" })));
    store.put(Setting::new("tenant-b", "hook/1", "webhook", json!({ "url": "https://rp.example/2" })));

    let hooks = store.query_kind("tenant-a", "webhook").await;
    assert_eq!(hooks.len(), 1);
    assert_eq!(hooks[0].value["url"], "https://rp.example/1");
}

#[tokio::test(start_paused = true)]
async fn putting_a_setting_again_replaces_it() {
    let store = SettingsStore::new();
    store.put(Setting::new("tenant-a", "hook/1", "webhook", json!({ "url": "https://rp.example/old" })));
    store.put(Setting::new("tenant-a", "hook/1", "webhook", json!({ "url": "https://rp.example/new" })));

    let page = store.query("tenant-a", None).await;
    assert_eq!(page.items.len(), 1);
    assert_eq!(page.items[0].value["url"], "https://rp.example/new");
    assert_eq!(store.query_kind("tenant-a", "webhook").await.len(), 1);
}
