// EXAMINER-ONLY robustness probes, wallet half (non-blocking). Stripped from the learner clone with
// the rest of _solutions/. NOT part of the graded gate: `grade.sh` never runs this file, and its
// result never changes the gate's pass/fail or exit code. `_solutions/robustness-probes.sh` copies it
// into a temp copy of `app/test/` and runs it headless (`flutter test --no-pub`).
//
// Each test is one probe, named `robustness <id>: ...`. They drive vectors the frozen feature gate
// (axis b) does not see:
//   W1, W2  held state handed out by reference (the wallet store, latent #2);
//   W3      the presentation path shares no state with the held credential, in either direction;
//   G1      the holder-binding guard sits on the presentation, not only on `requestCredential`;
//   D1      a DCQL query that names no claim discloses nothing, and the presentation is still
//           holder-signed and bound (degenerate query);
//   D2      a DCQL query for a claim the credential does not hold is refused rather than answered
//           with a presentation that silently omits it (degenerate query).
//
// No probe pins the expiry instant (`expires_at == now`): that boundary is latent #4, deliberately
// unspecified, and a probe must not decide it.
//
// Self-contained: the credential is built here (no issuer, no network), issued to the did:key of seed
// [7; 32], with `expires_at` in 2100. The probes do not check the issuer's signature or the `_sd`
// digests; the backend verifier's cross-stack checks are the gate's job.

import 'dart:convert';
import 'dart:typed_data';

import 'package:credentials_app/credentials_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi/ssi.dart';

final Uint8List probeSeed = Uint8List.fromList(List.filled(32, 7));
final HolderKey probeKey = HolderKey.fromSeed(probeSeed);

const farFuture = 4102444800; // 2100-01-01T00:00:00Z

Map<String, dynamic> issuance({
  required String id,
  String? subject,
}) => {
  'credential': {
    '@context': ['https://www.w3.org/2018/credentials/v1'],
    'id': id,
    'type': ['VerifiableCredential', 'MembershipCredential'],
    'issuer': 'did:web:members.harbourclub.example',
    'issued_at': 1777680000,
    'not_before': 1777680000,
    'expires_at': farFuture,
    'credentialSubject': {
      'id': subject ?? probeKey.did,
      '_sd': ['probe-digest-1', 'probe-digest-2', 'probe-digest-3', 'probe-digest-4'],
    },
    'credentialStatus': {
      'type': 'StatusListEntry',
      'statusListId': 'did:web:members.harbourclub.example#revocation',
      'statusListIndex': 7,
    },
    'proof': {
      'type': 'Ed25519Signature2020',
      'created': 1777680000,
      'verificationMethod': 'did:web:members.harbourclub.example#key-1',
      'proofPurpose': 'assertionMethod',
      'proofValue': 'zProbeIssuerProofNotChecked',
    },
  },
  'disclosures': [
    {'salt': 'cHJvYmUtbWVtYmVy', 'name': 'member', 'value': true},
    {'salt': 'cHJvYmUtbWVtYmVySWQ', 'name': 'memberId', 'value': 'M-40711'},
    {'salt': 'cHJvYmUtbmFtZQ', 'name': 'name', 'value': 'Rui Tanaka'},
    {'salt': 'cHJvYmUtYmlydGhEYXRl', 'name': 'birthDate', 'value': '1988-11-03'},
  ],
};

class _NoIssuer implements IssuerClient {
  @override
  Future<HeldCredential> issue({
    required String holderDid,
    required String credentialType,
  }) => throw StateError('the probes never request a credential');
}

/// A wallet whose store already holds [credentials].
WalletService walletHolding(List<HeldCredential> credentials) {
  final store = CredentialStore();
  for (final c in credentials) {
    store.save(c);
  }
  return WalletService(
    issuer: _NoIssuer(),
    store: store,
    newKey: () => HolderKey.fromSeed(probeSeed),
  );
}

PresentationRequest request({List<String>? claims, String nonce = 'n-probe-6Rt1'}) =>
    PresentationRequest.fromJson({
      'client_id': 'door.harbourclub.example',
      'nonce': nonce,
      'dcql_query': {
        'credentials': [
          {
            'id': 'membership',
            'format': 'ldp_vc',
            if (claims != null)
              'claims': [
                for (final name in claims)
                  {
                    'path': ['credentialSubject', name],
                  },
              ],
          },
        ],
      },
    });

String snapshot(Object? value) => jsonEncode(value);

/// The holder proof, checked the way the verifier does. Null when it holds.
Future<String?> holderProofProblem(Map<String, dynamic> vp) async {
  final proof = vp['proof'];
  if (proof is! Map) return 'no proof';
  if (proof['verificationMethod'] != probeKey.keyId) return 'proof is not by the holder key';
  final value = proof['proofValue'];
  if (value is! String) return 'no proofValue';
  final Uint8List signature;
  try {
    signature = multiBaseToUint8List(value);
  } on Object {
    return 'proofValue does not decode';
  }
  final unsigned = Map<String, dynamic>.of(vp)..remove('proof');
  final ok = await probeKey.verify(utf8.encode(JcsUtil.canonicalize(unsigned)), signature);
  return ok ? null : 'holder signature does not verify over the presentation';
}

/// Runs [build] and returns the refusal it raised, or null when it built something.
/// An unimplemented feature is not a refusal.
Future<Object?> refusalOf(Future<Object?> Function() build) async {
  try {
    await build();
    return null;
  } on UnimplementedError {
    rethrow;
  } on Object catch (e) {
    return e;
  }
}

void main() {
  test('robustness W1: a credential read from the wallet cannot change what the wallet holds', () {
    final held = HeldCredential.fromIssuance(issuance(id: 'urn:uuid:probe-w1'));
    final wallet = walletHolding([held]);
    final before = snapshot(wallet.credential('urn:uuid:probe-w1')!.toJson());
    try {
      final read = wallet.credential('urn:uuid:probe-w1')!;
      read.disclosures.clear();
      (read.vc['credentialSubject'] as Map)['id'] = 'did:key:zProbeIntruder';
    } on UnsupportedError {
      // an unmodifiable view is a valid defence
    }
    if (snapshot(wallet.credential('urn:uuid:probe-w1')!.toJson()) != before) {
      fail('editing the credential that credential(id) returned changed the one the wallet holds');
    }
  });

  test('robustness W2: an element of heldCredentials() cannot change what the wallet holds', () {
    final held = HeldCredential.fromIssuance(issuance(id: 'urn:uuid:probe-w2'));
    final wallet = walletHolding([held]);
    final before = snapshot(wallet.credential('urn:uuid:probe-w2')!.toJson());
    try {
      final listed = wallet.heldCredentials().single;
      listed.vc['expires_at'] = 1;
      listed.disclosures.removeWhere((d) => d.name == 'member');
    } on UnsupportedError {
      // an unmodifiable view is a valid defence
    }
    if (snapshot(wallet.credential('urn:uuid:probe-w2')!.toJson()) != before) {
      fail('editing an element of heldCredentials() changed the credential the wallet holds');
    }
  });

  test('robustness W3: a presentation shares no state with the held credential', () async {
    final wallet = walletHolding([
      HeldCredential.fromIssuance(issuance(id: 'urn:uuid:probe-w3')),
    ]);
    final heldBefore = snapshot(wallet.credential('urn:uuid:probe-w3')!.toJson());
    final vp = await wallet.createPresentation('urn:uuid:probe-w3', request(claims: ['member']));
    final vpBefore = snapshot(vp);

    // outward: editing the presentation handed out must not edit the wallet
    try {
      final vc = vp['verifiableCredential'] as Map;
      (vc['credentialSubject'] as Map)['id'] = 'did:key:zProbeIntruder';
      vc['expires_at'] = 1;
      final disclosures = vp['disclosures'];
      if (disclosures is List && disclosures.isNotEmpty) {
        final first = disclosures.first;
        if (first is Map) first['value'] = false;
      }
    } on UnsupportedError {
      // an unmodifiable presentation is a valid defence
    }
    if (snapshot(wallet.credential('urn:uuid:probe-w3')!.toJson()) != heldBefore) {
      fail('editing the presentation changed the held credential');
    }

    // inward: editing the wallet afterwards must not edit a presentation already built
    final fresh = await wallet.createPresentation('urn:uuid:probe-w3', request(claims: ['member']));
    final freshBefore = snapshot(fresh);
    final stored = wallet.credential('urn:uuid:probe-w3')!;
    try {
      stored.vc['issuer'] = 'did:web:intruder.example';
      final member = stored.disclosures.firstWhere((d) => d.name == 'member');
      stored.disclosures
        ..remove(member)
        ..add(Disclosure(salt: member.salt, name: member.name, value: false));
    } on UnsupportedError {
      // the store's own defence also closes this direction
    }
    if (snapshot(fresh) != freshBefore) {
      fail('editing the wallet changed a presentation already built');
    }
    final problem = await holderProofProblem(fresh);
    if (problem != null) fail('the built presentation no longer verifies: $problem');
    expect(vpBefore, isNotEmpty);
  });

  test('robustness G1: a credential bound to another holder is refused even when it bypassed requestCredential', () async {
    // requestCredential checks the binding; the store does not. The invariant belongs on the presentation.
    final wallet = walletHolding([
      HeldCredential.fromIssuance(
        issuance(id: 'urn:uuid:probe-g1', subject: 'did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK'),
      ),
    ]);
    final refusal = await refusalOf(
      () => wallet.createPresentation('urn:uuid:probe-g1', request(claims: ['member'])),
    );
    expect(refusal, isNotNull, reason: 'a presentation was built for a credential bound to another holder');
  });

  test('robustness D1: a query that names no claim discloses nothing and is still signed and bound', () async {
    final wallet = walletHolding([
      HeldCredential.fromIssuance(issuance(id: 'urn:uuid:probe-d1')),
    ]);
    final vp = jsonDecode(
      jsonEncode(await wallet.createPresentation('urn:uuid:probe-d1', request(nonce: 'n-probe-d1-Zk4'))),
    ) as Map<String, dynamic>;
    final disclosures = vp['disclosures'];
    expect(disclosures is List ? disclosures : const [], isEmpty, reason: 'claims were disclosed to a query that asked for none');
    for (final salt in ['cHJvYmUtbWVtYmVy', 'cHJvYmUtbWVtYmVySWQ', 'cHJvYmUtbmFtZQ', 'cHJvYmUtYmlydGhEYXRl']) {
      expect(jsonEncode(vp).contains(salt), isFalse, reason: 'a withheld claim travelled');
    }
    expect(vp['nonce'], 'n-probe-d1-Zk4');
    expect(vp['domain'], 'door.harbourclub.example');
    final problem = await holderProofProblem(vp);
    if (problem != null) fail(problem);
  });

  test('robustness D2: a query for a claim the credential does not hold is refused, not half-answered', () async {
    final wallet = walletHolding([
      HeldCredential.fromIssuance(issuance(id: 'urn:uuid:probe-d2')),
    ]);
    final refusal = await refusalOf(
      () => wallet.createPresentation('urn:uuid:probe-d2', request(claims: ['member', 'tier'])),
    );
    expect(refusal, isNotNull, reason: 'a presentation was built for a query the credential cannot satisfy');
  });
}
