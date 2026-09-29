//! Issuer and verifier service for membership credentials.
//!
//! - [`issuer`] onboards issuers and signs credentials for their members.
//! - [`verifier`] checks the presentations members show at the door.
//! - [`resolver`] turns a DID into its DID document; [`transport`] fetches
//!   the documents that are hosted rather than encoded in the DID.
//! - [`status`] and [`store`] keep issued credentials and their revocation state.
//! - [`notifier`] tells subscribed relying parties when a status changes;
//!   [`settings`] holds the tenants' subscriptions and [`webhook`] sends the
//!   calls.
//! - [`credential`] is the wire format shared by all of the above.

pub mod credential;
pub mod issuer;
pub mod notifier;
pub mod resolver;
pub mod settings;
pub mod status;
pub mod store;
pub mod transport;
pub mod verifier;
pub mod webhook;
