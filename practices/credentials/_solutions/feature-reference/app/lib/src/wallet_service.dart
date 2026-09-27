import 'dart:convert';

import 'package:ssi/ssi.dart';

import 'credential_store.dart';
import 'dcql_selection.dart';
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
  ///
  /// The presentation carries the issuer-signed credential unchanged plus only
  /// the disclosures the request's DCQL query asks for, names the requester's
  /// `nonce` and `domain`, and is signed by the holder's did:key key
  /// (`Ed25519Signature2020` over the JCS form of everything but the proof), so
  /// it cannot be replayed to another scanner or edited on the way. An expired
  /// credential is refused with a [WalletException].
  Future<Map<String, dynamic>> createPresentation(
    String credentialId,
    PresentationRequest request,
  ) async {
    final held = _store.byId(credentialId);
    if (held == null) {
      throw WalletException('No credential $credentialId in the wallet');
    }
    final key = holderKey();
    if (held.holderDid != key.did) {
      throw WalletException(
        'Credential $credentialId is bound to ${held.holderDid}, not ${key.did}',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = _expiresAt(held.vc);
    if (expiresAt != null && now >= expiresAt) {
      throw WalletException('Credential $credentialId has expired');
    }

    final disclosures = selectDisclosures(held, request.dcqlQuery);

    // A deep copy: the presentation never shares state with the held credential.
    final presentation = <String, dynamic>{
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      'type': ['VerifiablePresentation'],
      'holder': key.did,
      'verifiableCredential': jsonDecode(jsonEncode(held.vc)),
      'disclosures': [for (final d in disclosures) d.toJson()],
      'nonce': request.nonce,
      'domain': request.domain,
    };
    final signature = await key.sign(
      utf8.encode(JcsUtil.canonicalize(presentation)),
    );
    presentation['proof'] = {
      'type': 'Ed25519Signature2020',
      'created': now,
      'verificationMethod': key.keyId,
      'proofPurpose': 'authentication',
      'proofValue': toMultiBase(signature),
    };
    return presentation;
  }

  /// The credential's expiry in unix seconds: the issuer's `expires_at`, or a
  /// W3C `validUntil` / `expirationDate` timestamp; null when it has none.
  static int? _expiresAt(Map<String, dynamic> vc) {
    final seconds = vc['expires_at'];
    if (seconds is int) return seconds;
    for (final field in ['validUntil', 'expirationDate']) {
      final value = vc[field];
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed == null) {
          throw WalletException('Unreadable $field: $value');
        }
        return parsed.millisecondsSinceEpoch ~/ 1000;
      }
    }
    return null;
  }
}
