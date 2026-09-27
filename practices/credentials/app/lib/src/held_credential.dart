/// One salted claim the holder can reveal: its digest sits in the credential.
class Disclosure {
  const Disclosure({
    required this.salt,
    required this.name,
    required this.value,
  });

  factory Disclosure.fromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      return Disclosure(
        salt: json['salt'] as String,
        name: json['name'] as String,
        value: json['value'],
      );
    }
    if (json is List && json.length == 3) {
      return Disclosure(
        salt: json[0] as String,
        name: json[1] as String,
        value: json[2],
      );
    }
    throw FormatException('Unrecognised disclosure: $json');
  }

  final String salt;
  final String name;
  final Object? value;

  Map<String, dynamic> toJson() => {'salt': salt, 'name': name, 'value': value};
}

/// A credential in the wallet: the issuer-signed document plus the
/// disclosures that go with it.
class HeldCredential {
  HeldCredential({required this.vc, required this.disclosures});

  /// Parses the issuer's response: `{"credential": {...}, "disclosures": [...]}`.
  factory HeldCredential.fromIssuance(Map<String, dynamic> json) {
    final vc = json['credential'];
    if (vc is! Map<String, dynamic>) {
      throw const FormatException('Issuance response has no credential');
    }
    final disclosures = (json['disclosures'] as List? ?? const [])
        .map(Disclosure.fromJson)
        .toList();
    return HeldCredential(vc: vc, disclosures: disclosures);
  }

  final Map<String, dynamic> vc;
  final List<Disclosure> disclosures;

  String get id => vc['id'] as String;

  String get issuer {
    final issuer = vc['issuer'];
    return issuer is Map ? issuer['id'] as String : issuer as String;
  }

  String? get holderDid =>
      (vc['credentialSubject'] as Map<String, dynamic>?)?['id'] as String?;

  /// The most specific type, e.g. `MembershipCredential`.
  String get type {
    final types = vc['type'];
    return types is List ? types.last as String : types as String;
  }

  Map<String, dynamic> toJson() => {
    'credential': vc,
    'disclosures': disclosures.map((d) => d.toJson()).toList(),
  };
}
