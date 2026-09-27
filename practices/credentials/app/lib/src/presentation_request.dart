import 'package:dcql/dcql.dart';

/// A verifier's request for a presentation, in the OpenID4VP shape:
/// who is asking (`client_id`), a `nonce`, and a DCQL query.
class PresentationRequest {
  const PresentationRequest({
    required this.clientId,
    required this.nonce,
    required this.dcqlQuery,
    this.responseUri,
  });

  factory PresentationRequest.fromJson(Map<String, dynamic> json) {
    final clientId = json['client_id'];
    final nonce = json['nonce'];
    final query = json['dcql_query'];
    if (clientId is! String || clientId.isEmpty) {
      throw const FormatException('Presentation request has no client_id');
    }
    if (nonce is! String || nonce.isEmpty) {
      throw const FormatException('Presentation request has no nonce');
    }
    if (query is! Map<String, dynamic>) {
      throw const FormatException('Presentation request has no dcql_query');
    }
    final responseUri = json['response_uri'];
    return PresentationRequest(
      clientId: clientId,
      nonce: nonce,
      dcqlQuery: DcqlCredentialQuery.fromJson(query),
      responseUri: responseUri is String ? Uri.parse(responseUri) : null,
    );
  }

  final String clientId;
  final String nonce;
  final DcqlCredentialQuery dcqlQuery;
  final Uri? responseUri;

  /// The domain a presentation for this request is addressed to.
  String get domain => clientId;

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'nonce': nonce,
    'dcql_query': dcqlQuery.toJson(),
    if (responseUri != null) 'response_uri': responseUri.toString(),
  };
}
