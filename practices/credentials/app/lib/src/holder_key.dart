import 'dart:typed_data';

import 'package:ssi/ssi.dart';

/// The holder's signing key and the did:key derived from it.
class HolderKey {
  HolderKey._(this.keyPair) : did = DidKey.getDid(keyPair.publicKey);

  /// A fresh random Ed25519 key.
  factory HolderKey.generate() {
    final (keyPair, _) = Ed25519KeyPair.generate();
    return HolderKey._(keyPair);
  }

  /// A key restored from its 32-byte seed.
  factory HolderKey.fromSeed(Uint8List seed) =>
      HolderKey._(Ed25519KeyPair.fromSeed(seed));

  final Ed25519KeyPair keyPair;
  final String did;

  /// The verification method id inside the did:key document.
  String get keyId => '$did#${did.substring('did:key:'.length)}';

  Future<Uint8List> sign(List<int> data) =>
      keyPair.sign(Uint8List.fromList(data));

  Future<bool> verify(List<int> data, List<int> signature) =>
      keyPair.verify(Uint8List.fromList(data), Uint8List.fromList(signature));
}
