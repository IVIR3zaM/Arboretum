//! Issuer and verifier service for membership credentials.
//!
//! - [`issuer`] onboards issuers and signs credentials for their members.
//! - [`verifier`] checks the presentations members show at the door.
//! - [`resolver`] turns a DID into its DID document; [`transport`] fetches
//!   the documents that are hosted rather than encoded in the DID.
//! - [`status`] and [`store`] keep issued credentials and their revocation state.
//! - [`credential`] is the wire format shared by all of the above.

pub mod credential;
pub mod issuer;
pub mod resolver;
pub mod status;
pub mod store;
pub mod transport;
pub mod verifier;
