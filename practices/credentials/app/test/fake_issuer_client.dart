import 'package:credentials_app/credentials_app.dart';

import 'fixtures.dart';

class FakeIssuerClient implements IssuerClient {
  FakeIssuerClient({this.subjectOverride});

  /// When set, the issued credential names this subject instead of the caller.
  final String? subjectOverride;

  final List<({String holderDid, String credentialType})> calls = [];

  @override
  Future<HeldCredential> issue({
    required String holderDid,
    required String credentialType,
  }) async {
    calls.add((holderDid: holderDid, credentialType: credentialType));
    return HeldCredential.fromIssuance(
      membershipIssuance(subject: subjectOverride ?? holderDid),
    );
  }
}
