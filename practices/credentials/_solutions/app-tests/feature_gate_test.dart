// Axis (b), wallet half: the hidden phase-3 feature gate for
// `WalletService.createPresentation(credentialId, request)`.
//
// Copied into a temporary grading copy of `app/test/` by `grade.d/b.sh`, which first writes the
// issuance responses this file reads into `test/gate/` (issued by the backend's own `Issuer`, from
// the never-rotated Harbour Club did:web, to the did:key of seed [7; 32]). The four `feature:` tests
// are scored; the `emit:` test writes `test/gate/out/vp.json` for the Rust cross-stack cases and is
// not scored on its own.
//
// Headless (`flutter test --no-pub`), no device, no network, no `integration_test/`.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:credentials_app/credentials_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi/ssi.dart';

final Uint8List gateHolderSeed = Uint8List.fromList(List.filled(32, 7));

Map<String, dynamic> readGate(String name) =>
    jsonDecode(File('test/gate/$name').readAsStringSync())
        as Map<String, dynamic>;

/// A fresh wallet holding the gate's credentials, keyed to the gate's holder seed.
({WalletService wallet, HeldCredential valid, HeldCredential expired})
gateWallet() {
  final store = CredentialStore();
  final valid = HeldCredential.fromIssuance(readGate('issued-valid.json'));
  final expired = HeldCredential.fromIssuance(readGate('issued-expired.json'));
  store.save(valid);
  store.save(expired);
  final wallet = WalletService(
    issuer: _NoIssuer(),
    store: store,
    newKey: () => HolderKey.fromSeed(gateHolderSeed),
  );
  return (wallet: wallet, valid: valid, expired: expired);
}

class _NoIssuer implements IssuerClient {
  @override
  Future<HeldCredential> issue({
    required String holderDid,
    required String credentialType,
  }) => throw StateError('the gate never requests a credential');
}

PresentationRequest doorRequest({
  String clientId = 'door.harbourclub.example',
  String nonce = 'n-gate-7Qm2VxR4',
  List<String> claims = const ['member'],
}) => PresentationRequest.fromJson({
  'client_id': clientId,
  'nonce': nonce,
  'response_uri': 'https://$clientId/presentations',
  'dcql_query': {
    'credentials': [
      {
        'id': 'membership',
        'format': 'ldp_vc',
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

/// The presentation as it goes over the wire: JSON-encodable, decoded back.
Map<String, dynamic> onTheWire(Map<String, dynamic> vp) =>
    jsonDecode(jsonEncode(vp)) as Map<String, dynamic>;

List<Map<String, dynamic>> disclosuresOf(Map<String, dynamic> vp) {
  final list = vp['disclosures'];
  if (list is! List) return const [];
  return list.whereType<Map<String, dynamic>>().toList();
}

/// Checks the holder proof the way the verifier does: an `Ed25519Signature2020` proof, for
/// `authentication`, by the holder's did:key key, over the RFC 8785 (JCS) bytes of the
/// presentation without its `proof`. Returns null when it holds, else what is wrong.
Future<String?> holderProofProblem(
  Map<String, dynamic> vp,
  HolderKey key,
) async {
  if (vp['holder'] != key.did) {
    return 'holder is ${vp['holder']}, expected ${key.did}';
  }
  final proof = vp['proof'];
  if (proof is! Map<String, dynamic>) return 'no proof';
  if (proof['type'] != 'Ed25519Signature2020') {
    return 'proof.type is ${proof['type']}, expected Ed25519Signature2020';
  }
  if (proof['proofPurpose'] != 'authentication') {
    return 'proof.proofPurpose is ${proof['proofPurpose']}, expected authentication';
  }
  if (proof['verificationMethod'] != key.keyId) {
    return 'proof.verificationMethod is ${proof['verificationMethod']}, expected ${key.keyId}';
  }
  final value = proof['proofValue'];
  if (value is! String || !value.startsWith('z')) {
    return 'proof.proofValue is not multibase base58btc';
  }
  final Uint8List signature;
  try {
    signature = multiBaseToUint8List(value);
  } on Object {
    return 'proof.proofValue does not decode';
  }
  final unsigned = Map<String, dynamic>.of(vp)..remove('proof');
  final input = utf8.encode(JcsUtil.canonicalize(unsigned));
  if (!await key.verify(input, signature)) {
    return 'holder signature does not verify over the presentation';
  }
  return null;
}

void main() {
  test('gate fixtures are issued to the gate holder', () {
    final gate = gateWallet();
    final holder = HolderKey.fromSeed(gateHolderSeed).did;
    expect(readGate('holder.json')['did'], holder);
    expect(gate.valid.holderDid, holder);
    expect(gate.expired.holderDid, holder);
  });

  test(
    'feature: discloses exactly the claims the DCQL query asks for',
    () async {
      final gate = gateWallet();
      for (final asked in [
        ['member'],
        ['memberId', 'name'],
      ]) {
        final vp = onTheWire(
          await gate.wallet.createPresentation(
            gate.valid.id,
            doorRequest(claims: asked),
          ),
        );
        final disclosed = disclosuresOf(vp);
        expect(
          disclosed.map((d) => d['name']).toSet(),
          asked.toSet(),
          reason: 'a query for $asked must disclose exactly $asked',
        );
        expect(disclosed, hasLength(asked.length));
        for (final d in disclosed) {
          final held = gate.valid.disclosures.singleWhere(
            (h) => h.name == d['name'],
          );
          expect(d, held.toJson(), reason: 'disclosed as issued');
        }
        expect(
          vp['verifiableCredential'],
          onTheWire(gate.valid.vc),
          reason: 'the issuer-signed credential travels unchanged',
        );
        final withheld = gate.valid.disclosures.where(
          (h) => !asked.contains(h.name),
        );
        final wire = jsonEncode(vp);
        for (final h in withheld) {
          expect(
            wire.contains(h.salt),
            isFalse,
            reason: '${h.name} was not asked for and must not travel',
          );
        }
      }
    },
  );

  test('feature: the presentation is signed by the holder\'s key', () async {
    final gate = gateWallet();
    final vp = onTheWire(
      await gate.wallet.createPresentation(gate.valid.id, doorRequest()),
    );
    expect(
      await holderProofProblem(vp, HolderKey.fromSeed(gateHolderSeed)),
      isNull,
    );
    expect(
      vp['verifiableCredential'],
      onTheWire(gate.valid.vc),
      reason: 'the holder proof wraps the issuer-signed credential',
    );
  });

  test(
    'feature: the presentation is bound to the request\'s nonce and domain',
    () async {
      final gate = gateWallet();
      final key = HolderKey.fromSeed(gateHolderSeed);
      final first = doorRequest(
        clientId: 'door.harbourclub.example',
        nonce: 'n-gate-first-3Jd8',
      );
      final second = doorRequest(
        clientId: 'bar.harbourclub.example',
        nonce: 'n-gate-second-Pw5c',
      );
      for (final request in [first, second]) {
        final vp = onTheWire(
          await gate.wallet.createPresentation(gate.valid.id, request),
        );
        expect(vp['nonce'], request.nonce);
        expect(vp['domain'], request.domain);
        expect(
          await holderProofProblem(vp, key),
          isNull,
          reason: 'nonce and domain count only under the holder proof',
        );
      }
    },
  );

  test('feature: an expired credential is refused', () async {
    final gate = gateWallet();
    await gate.wallet.createPresentation(gate.valid.id, doorRequest());
    Map<String, dynamic>? vp;
    Object? refusal;
    try {
      vp = await gate.wallet.createPresentation(gate.expired.id, doorRequest());
    } on UnimplementedError {
      rethrow;
    } on Object catch (e) {
      refusal = e;
    }
    expect(vp, isNull, reason: 'no presentation of an expired credential');
    expect(refusal, isNotNull);
  });

  test('emit: presentation for the cross-stack check', () async {
    final gate = gateWallet();
    final request = doorRequest();
    final vp = await gate.wallet.createPresentation(gate.valid.id, request);
    final out = File('test/gate/out/vp.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
      jsonEncode({
        'nonce': request.nonce,
        'domain': request.domain,
        'presentation': vp,
      }),
    );
  });
}
