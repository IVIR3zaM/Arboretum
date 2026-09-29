import 'credential_store.dart';
import 'held_credential.dart';
import 'holder_key.dart';
import 'issuer_client.dart';
import 'presentation_request.dart';

class WalletException implements Exception {
  const WalletException(this.message);
  final String message;
  @override
  String toString() => 'WalletException: $message';
}

/// The wallet's operations: holder key, credential requests, presentations.
class WalletService {
  WalletService({
    required this._issuer,
    CredentialStore? store,
    HolderKey Function()? newKey,
  }) : _store = store ?? CredentialStore(),
       _newKey = newKey ?? HolderKey.generate;

  final IssuerClient _issuer;
  final CredentialStore _store;
  final HolderKey Function() _newKey;

  /// The holder key, created on first use.
  HolderKey holderKey() => _store.holderKey ??= _newKey();

  /// Requests a [credentialType] credential for this holder and keeps it.
  Future<HeldCredential> requestCredential(String credentialType) async {
    final did = holderKey().did;
    final credential = await _issuer.issue(
      holderDid: did,
      credentialType: credentialType,
    );
    if (credential.holderDid != did) {
      throw WalletException(
        'Credential ${credential.id} was issued to ${credential.holderDid}, not $did',
      );
    }
    _store.save(credential);
    return credential;
  }

  List<HeldCredential> heldCredentials() => _store.all();

  HeldCredential? credential(String id) => _store.byId(id);

  /// Builds a presentation of the held credential [credentialId] in answer
  /// to [request], ready to send to the requester.
  Future<Map<String, dynamic>> createPresentation(
    String credentialId,
    PresentationRequest request,
  ) async {
    throw UnimplementedError('createPresentation');
  }
}
