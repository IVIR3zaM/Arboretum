// Smoke test: imports the pinned Affinidi packages `ssi` and `dcql` and
// exercises one offline, non-network call from each, checking that both
// packages resolve and are wired up correctly. No did:web resolution, no I/O.

import 'package:flutter_test/flutter_test.dart';
import 'package:ssi/ssi.dart';
import 'package:dcql/dcql.dart';

void main() {
  test('generates an Ed25519 key pair via the ssi package', () {
    final (keyPair, privateKeyBytes) = Ed25519KeyPair.generate();
    expect(keyPair.id, isNotEmpty);
    expect(privateKeyBytes, isNotEmpty);
  });

  test('builds a DCQL credential query via the dcql package', () {
    final query = DcqlCredentialQuery(
      credentials: [
        DcqlCredential(id: 'cred1', format: CredentialFormat.jwtVcJson),
      ],
    );
    expect(query.credentials, hasLength(1));
  });
}
