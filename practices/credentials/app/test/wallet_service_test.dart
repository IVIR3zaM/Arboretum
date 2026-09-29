import 'package:credentials_app/credentials_app.dart';
import 'package:dcql/dcql.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_issuer_client.dart';
import 'fixtures.dart';

void main() {
  test('creates a holder key once and reuses it', () {
    final wallet = WalletService(issuer: FakeIssuerClient());
    final first = wallet.holderKey();
    expect(first.did, startsWith('did:key:'));
    expect(wallet.holderKey().did, first.did);
  });

  test('requests a credential for the holder DID and stores it', () async {
    final client = FakeIssuerClient();
    final wallet = WalletService(
      issuer: client,
      newKey: () => HolderKey.fromSeed(holderSeed),
    );

    final credential = await wallet.requestCredential('MembershipCredential');

    expect(client.calls.single.holderDid, holderDid);
    expect(client.calls.single.credentialType, 'MembershipCredential');
    expect(credential.holderDid, holderDid);
    expect(wallet.heldCredentials().map((c) => c.id), [credential.id]);
  });

  test('refuses a credential issued to someone else', () async {
    final wallet = WalletService(
      issuer: FakeIssuerClient(subjectOverride: 'did:key:z6MkSomeoneElse'),
    );
    await expectLater(
      wallet.requestCredential('MembershipCredential'),
      throwsA(isA<WalletException>()),
    );
    expect(wallet.heldCredentials(), isEmpty);
  });

  test('parses a presentation request', () {
    final request = PresentationRequest.fromJson(doorRequest());
    expect(request.nonce, 'n-8f3Kq2xWz0Lb');
    expect(request.domain, 'door-scanner.members.test');
    expect(
      request.responseUri,
      Uri.parse('https://door-scanner.members.test/presentations'),
    );
    final credential = request.dcqlQuery.credentials.single;
    expect(credential.id, 'membership');
    expect(credential.format, CredentialFormat.ldpVc);
    expect(credential.claims!.single.path, ['credentialSubject', 'member']);
  });

  test('rejects a presentation request without a nonce', () {
    final json = doorRequest()..remove('nonce');
    expect(() => PresentationRequest.fromJson(json), throwsFormatException);
  });
}
