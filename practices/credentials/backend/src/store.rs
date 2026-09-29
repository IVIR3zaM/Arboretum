//! In-memory state: onboarded issuers, issued credentials and status lists.

use std::collections::HashMap;
use std::sync::Mutex;

use affinidi_did_common::Document;
use serde::{Deserialize, Serialize};

use crate::status::{StatusList, DEFAULT_CAPACITY};

const ONBOARDING_DATA: &str = include_str!("../data/onboarded-issuers.json");

/// An issuer approved to issue through the service.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct OnboardedIssuer {
    pub did: String,
    pub name: String,
    pub onboarded_at: String,
    pub document: Document,
}

/// What the service remembers about a credential it issued.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CredentialRecord {
    pub id: String,
    pub issuer: String,
    pub subject: String,
    pub status_list: String,
    pub status_index: usize,
    pub expires_at: i64,
}

#[derive(Default)]
struct Inner {
    issuers: HashMap<String, OnboardedIssuer>,
    credentials: HashMap<String, CredentialRecord>,
    status_lists: HashMap<String, StatusList>,
}

#[derive(Default)]
pub struct Store {
    inner: Mutex<Inner>,
}

impl Store {
    pub fn new() -> Self {
        Store::default()
    }

    /// A store holding every issuer in `data/onboarded-issuers.json`.
    pub fn from_onboarding_data() -> Result<Self, serde_json::Error> {
        let issuers: Vec<OnboardedIssuer> = serde_json::from_str(ONBOARDING_DATA)?;
        let store = Store::new();
        for issuer in issuers {
            store.record_onboarded_issuer(issuer);
        }
        Ok(store)
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Inner> {
        self.inner.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    pub fn record_onboarded_issuer(&self, issuer: OnboardedIssuer) {
        self.lock().issuers.insert(issuer.did.clone(), issuer);
    }

    /// Issuer documents are self-contained, as with the peer DIDs issuers
    /// first onboarded with: keys and service endpoints travel with the
    /// document, so the copy recorded at onboarding is all verification needs.
    pub fn onboarded_issuer(&self, did: &str) -> Option<OnboardedIssuer> {
        self.lock().issuers.get(did).cloned()
    }

    pub fn onboarded_issuers(&self) -> Vec<OnboardedIssuer> {
        let mut issuers: Vec<_> = self.lock().issuers.values().cloned().collect();
        issuers.sort_by(|a, b| a.did.cmp(&b.did));
        issuers
    }

    pub fn record_credential(&self, record: CredentialRecord) {
        self.lock().credentials.insert(record.id.clone(), record);
    }

    pub fn credential(&self, id: &str) -> Option<CredentialRecord> {
        self.lock().credentials.get(id).cloned()
    }

    /// Reserves an index in `list`, creating the list on first use.
    pub fn allocate_status_index(&self, list: &str) -> Option<usize> {
        self.lock()
            .status_lists
            .entry(list.to_string())
            .or_insert_with(|| StatusList::new(DEFAULT_CAPACITY))
            .allocate()
    }

    /// Sets the bit at `index` in `list`; `false` if there is no such list.
    pub fn set_status(&self, list: &str, index: usize, revoked: bool) -> bool {
        match self.lock().status_lists.get_mut(list) {
            Some(status) => {
                status.set(index, revoked);
                true
            }
            None => false,
        }
    }

    pub fn is_revoked(&self, list: &str, index: usize) -> Option<bool> {
        self.lock().status_lists.get(list).map(|status| status.is_set(index))
    }

    /// The published form of `list`.
    pub fn encoded_status_list(&self, list: &str) -> Option<String> {
        self.lock().status_lists.get(list).map(StatusList::encode)
    }
}
