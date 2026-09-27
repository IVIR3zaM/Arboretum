import 'package:credentials_app/credentials_app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test('a generated holder key is an Ed25519 did:key', () {
    final key = HolderKey.generate();
    expect(key.did, startsWith('did:key:z6Mk'));
    expect(key.keyId, '${key.did}#${key.did.substring('did:key:'.length)}');
  });

  test('two generated keys have different DIDs', () {
    expect(HolderKey.generate().did, isNot(HolderKey.generate().did));
  });

  test('a key from a fixed seed has a stable DID', () {
    expect(HolderKey.fromSeed(holderSeed).did, holderDid);
  });

  test('the holder key signs with Ed25519', () async {
    final key = HolderKey.fromSeed(holderSeed);
    final data = [1, 2, 3];
    final signature = await key.sign(data);
    expect(signature, hasLength(64));
    expect(await key.verify(data, signature), isTrue);
  });
}
