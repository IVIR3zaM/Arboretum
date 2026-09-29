import 'held_credential.dart';
import 'holder_key.dart';

/// In-memory wallet storage: held credentials by id, and the holder key.
class CredentialStore {
  final Map<String, HeldCredential> _credentials = {};

  void save(HeldCredential credential) =>
      _credentials[credential.id] = credential;

  HeldCredential? byId(String id) => _credentials[id];

  List<HeldCredential> all() => List.unmodifiable(_credentials.values);

  HolderKey? holderKey;
}
