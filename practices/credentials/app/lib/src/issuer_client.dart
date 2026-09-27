import 'held_credential.dart';

/// Talks to the issuer service.
abstract interface class IssuerClient {
  /// Asks the issuer for a [credentialType] credential about [holderDid].
  Future<HeldCredential> issue({
    required String holderDid,
    required String credentialType,
  });
}
