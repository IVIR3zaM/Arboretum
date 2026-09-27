import 'package:credentials_app/credentials_app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  late CredentialStore store;
  setUp(() => store = CredentialStore());

  test('parses an issued credential with its disclosures', () {
    final credential = HeldCredential.fromIssuance(membershipIssuance());
    expect(credential.id, 'urn:uuid:5b1d7c2e-0f7a-4c3e-9d0b-6a2f1e8c4d11');
    expect(credential.issuer, issuerDid);
    expect(credential.holderDid, holderDid);
    expect(credential.type, 'MembershipCredential');
    expect(credential.disclosures.map((d) => d.name), [
      'member',
      'memberId',
      'name',
      'birthDate',
    ]);
    expect(credential.disclosures.first.value, true);
    expect(credential.disclosures.first.salt, 'Qg8wYx1dLr0pVb3kTz7sNw');
  });

  test('saves and finds a credential by id', () {
    final credential = HeldCredential.fromIssuance(membershipIssuance());
    store.save(credential);
    expect(store.byId(credential.id)?.issuer, issuerDid);
    expect(store.byId('urn:uuid:unknown'), isNull);
  });

  test('lists every held credential', () {
    expect(store.all(), isEmpty);
    store.save(HeldCredential.fromIssuance(membershipIssuance()));
    expect(store.all(), hasLength(1));
  });

  test('saving the same id twice keeps one copy', () {
    store.save(HeldCredential.fromIssuance(membershipIssuance()));
    store.save(HeldCredential.fromIssuance(membershipIssuance()));
    expect(store.all(), hasLength(1));
  });

  test('keeps the holder key', () {
    expect(store.holderKey, isNull);
    store.holderKey = HolderKey.fromSeed(holderSeed);
    expect(store.holderKey?.did, holderDid);
  });
}
