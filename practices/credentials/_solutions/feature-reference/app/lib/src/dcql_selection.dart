import 'package:dcql/dcql.dart';

import 'held_credential.dart';
import 'wallet_service.dart';

/// The disclosures of [held] that answer [query]: exactly the claims the
/// query's matched credential query names, nothing more.
///
/// The query is evaluated with the `dcql` package against a W3C view of the
/// credential in which every held claim is revealed; only the claims the query
/// asks for (per `claims`, or the first satisfied `claim_sets` option) are
/// then disclosed. A query with no `claims` asks for no selectively disclosable
/// claim, so none is disclosed.
List<Disclosure> selectDisclosures(
  HeldCredential held,
  DcqlCredentialQuery query,
) {
  final DigitalCredential view;
  try {
    view = W3CDigitalCredential.fromLdVcDataModelV1(_revealedView(held));
  } on Object catch (e) {
    throw WalletException('Credential ${held.id} cannot be queried: $e');
  }
  final result = query.query([view]);
  if (!result.fulfilled) {
    throw WalletException(
      'Credential ${held.id} does not satisfy the requested query',
    );
  }

  final names = <String>{};
  for (final requested in query.credentials) {
    if (result.verifiableCredentials[requested.id]?.isNotEmpty != true) {
      continue;
    }
    final claims = requested.claims ?? const <DcqlClaim>[];
    final satisfied = <String>{
      for (final set
          in result.satisfiedClaimsByCredential[requested.id] ??
              const <Set<String>>[])
        ...set,
    };
    final Set<String> chosen;
    final claimSets = requested.claimSets;
    if (claimSets == null) {
      chosen = {
        for (var i = 0; i < claims.length; i++) claims[i].getEffectiveId(i),
      };
    } else {
      chosen = claimSets
          .firstWhere((option) => option.every(satisfied.contains))
          .toSet();
    }
    for (var i = 0; i < claims.length; i++) {
      if (!chosen.contains(claims[i].getEffectiveId(i))) continue;
      final path = claims[i].path;
      if (path.length != 2 ||
          path[0] != 'credentialSubject' ||
          path[1] is! String) {
        throw WalletException('Unsupported claim path $path');
      }
      names.add(path[1] as String);
    }
  }
  return [
    for (final d in held.disclosures)
      if (names.contains(d.name)) d,
  ];
}

/// The credential as a W3C VC v1 document with every held claim revealed in
/// `credentialSubject` — used only to evaluate the query, never sent.
Map<String, dynamic> _revealedView(HeldCredential held) {
  final vc = held.vc;
  final issuedAt = vc['issued_at'];
  final issuanceDate = issuedAt is int
      ? DateTime.fromMillisecondsSinceEpoch(issuedAt * 1000, isUtc: true)
      : DateTime.tryParse('${vc['issuanceDate'] ?? vc['validFrom'] ?? ''}') ??
            DateTime.utc(1970);
  return {
    '@context': ['https://www.w3.org/2018/credentials/v1'],
    'id': held.id,
    'type': vc['type'],
    'issuer': held.issuer,
    'issuanceDate': issuanceDate.toUtc().toIso8601String(),
    'credentialSubject': {
      'id': held.holderDid,
      for (final d in held.disclosures) d.name: d.value,
    },
  };
}
