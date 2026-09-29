import 'dart:typed_data';

/// Seed of the holder key the fixture credential was issued to.
final Uint8List holderSeed = Uint8List.fromList(List.filled(32, 7));

const holderDid = 'did:key:z6MkvDqGT54cXesYGvABpF1UapVNwjCqRcafi4Px6Thv5T3Z';

const issuerDid = 'did:web:issuer.members.test';

/// Issuer response for a membership credential, as the issuer service returns it.
Map<String, dynamic> membershipIssuance({String subject = holderDid}) => {
  'credential': {
    '@context': ['https://www.w3.org/ns/credentials/v2'],
    'id': 'urn:uuid:5b1d7c2e-0f7a-4c3e-9d0b-6a2f1e8c4d11',
    'type': ['VerifiableCredential', 'MembershipCredential'],
    'issuer': issuerDid,
    'validFrom': '2026-01-01T00:00:00Z',
    'validUntil': '2027-01-01T00:00:00Z',
    'credentialSubject': {
      'id': subject,
      '_sd': [
        'JVmpmvr8l44m-VjhbllpxsgwyKDSC_EcWIdoCZj1SLs',
        'F8w8nFje9RpZ9F8EJ5jGh6BUWuAXz_umNdTgEBhpl5s',
        '51mkbb932Hakyr67b_toNlii0D2o6nhzAOxig4ii8Jk',
        'REwmh76r9rNH8My4qBGgDd7oG07vsiHQX2Qt-w-b8Qg',
      ],
    },
    'proof': {
      'type': 'DataIntegrityProof',
      'cryptosuite': 'eddsa-jcs-2022',
      'verificationMethod': '$issuerDid#key-1',
      'proofPurpose': 'assertionMethod',
      'proofValue': 'z3FXQjecWufY46yg5abdVZsXqLhxhueuSoZgNSARiKBk9czhSePTFehP8c3PGfb6a22gkfUKKy2Rj2cUk5WBLgmPs',
    },
  },
  'disclosures': [
    {'salt': 'Qg8wYx1dLr0pVb3kTz7sNw', 'name': 'member', 'value': true},
    {'salt': 'bM4rT9cZ2xKq1nVf0hJw8A', 'name': 'memberId', 'value': 'M-20417'},
    {'salt': 'u7EoH3pWq5sLd2yGk9rCzQ', 'name': 'name', 'value': 'Ada Park'},
    {
      'salt': 'X2nR6vBt1fYk8mJq4cLwEg',
      'name': 'birthDate',
      'value': '1990-04-12',
    },
  ],
};

/// A door-scanner request, shaped like an OpenID4VP authorization request.
Map<String, dynamic> doorRequest() => {
  'client_id': 'door-scanner.members.test',
  'nonce': 'n-8f3Kq2xWz0Lb',
  'response_uri': 'https://door-scanner.members.test/presentations',
  'dcql_query': {
    'credentials': [
      {
        'id': 'membership',
        'format': 'ldp_vc',
        'claims': [
          {
            'path': ['credentialSubject', 'member'],
          },
        ],
      },
    ],
  },
};
