//! Tenant settings: the in-repo stand-in for the `tenant-settings` table.
//!
//! Every tenant (an onboarded issuer, keyed by its DID) owns a partition of
//! settings, each identified by a key and tagged with a kind. Like the table,
//! a query returns a partition one page at a time in key order, and every
//! page read takes [`PAGE_READ_LATENCY`]. The `tenant-kind` index answers
//! "settings of this kind for this tenant" directly.

use std::collections::{BTreeMap, BTreeSet};
use std::ops::Bound;
use std::sync::Mutex;
use std::time::Duration;

use serde_json::Value;

/// Items returned per page read.
pub const PAGE_SIZE: usize = 100;

/// What one page read costs.
pub const PAGE_READ_LATENCY: Duration = Duration::from_millis(50);

#[derive(Debug, Clone, PartialEq)]
pub struct Setting {
    pub tenant: String,
    pub key: String,
    pub kind: String,
    pub value: Value,
}

impl Setting {
    pub fn new(tenant: &str, key: &str, kind: &str, value: Value) -> Self {
        Setting { tenant: tenant.to_string(), key: key.to_string(), kind: kind.to_string(), value }
    }
}

/// One page of a partition. `next` is the cursor for the following page,
/// `None` on the last one.
#[derive(Debug, Clone, PartialEq)]
pub struct Page {
    pub items: Vec<Setting>,
    pub next: Option<String>,
}

#[derive(Default)]
struct Inner {
    /// tenant → key → setting
    partitions: BTreeMap<String, BTreeMap<String, Setting>>,
    /// (tenant, kind) → keys
    by_kind: BTreeMap<(String, String), BTreeSet<String>>,
}

#[derive(Default)]
pub struct SettingsStore {
    inner: Mutex<Inner>,
}

impl SettingsStore {
    pub fn new() -> Self {
        SettingsStore::default()
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Inner> {
        self.inner.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    /// Writes `setting`, replacing any setting with the same tenant and key.
    pub fn put(&self, setting: Setting) {
        let mut inner = self.lock();
        let partition = inner.partitions.entry(setting.tenant.clone()).or_default();
        let previous = partition.insert(setting.key.clone(), setting.clone());
        if let Some(previous) = previous {
            if let Some(keys) = inner.by_kind.get_mut(&(previous.tenant, previous.kind)) {
                keys.remove(&previous.key);
            }
        }
        inner.by_kind.entry((setting.tenant, setting.kind)).or_default().insert(setting.key);
    }

    /// One page of `tenant`'s settings, starting after the key `after`.
    pub async fn query(&self, tenant: &str, after: Option<&str>) -> Page {
        tokio::time::sleep(PAGE_READ_LATENCY).await;
        let inner = self.lock();
        let Some(partition) = inner.partitions.get(tenant) else {
            return Page { items: Vec::new(), next: None };
        };
        let start = match after {
            Some(key) => Bound::Excluded(key.to_string()),
            None => Bound::Unbounded,
        };
        let mut range = partition.range((start, Bound::Unbounded));
        let items: Vec<Setting> = range.by_ref().take(PAGE_SIZE).map(|(_, s)| s.clone()).collect();
        let next = match range.next() {
            Some(_) => items.last().map(|s| s.key.clone()),
            None => None,
        };
        Page { items, next }
    }

    /// `tenant`'s settings of `kind`, through the `tenant-kind` index.
    pub async fn query_kind(&self, tenant: &str, kind: &str) -> Vec<Setting> {
        let items: Vec<Setting> = {
            let inner = self.lock();
            let keys = inner.by_kind.get(&(tenant.to_string(), kind.to_string()));
            let partition = inner.partitions.get(tenant);
            match (keys, partition) {
                (Some(keys), Some(partition)) => keys.iter().filter_map(|k| partition.get(k).cloned()).collect(),
                _ => Vec::new(),
            }
        };
        let pages = items.len().div_ceil(PAGE_SIZE).max(1) as u32;
        tokio::time::sleep(PAGE_READ_LATENCY * pages).await;
        items
    }
}
