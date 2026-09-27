import 'package:flutter/material.dart';

import 'held_credential.dart';
import 'wallet_service.dart';

class CredentialList extends StatelessWidget {
  const CredentialList({super.key, required this.credentials});

  final List<HeldCredential> credentials;

  @override
  Widget build(BuildContext context) {
    if (credentials.isEmpty) {
      return const Center(child: Text('No credentials yet'));
    }
    return ListView(
      children: [
        for (final credential in credentials)
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(credential.type),
            subtitle: Text(credential.issuer),
          ),
      ],
    );
  }
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.wallet});

  final WalletService wallet;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _busy = false;

  Future<void> _requestMembership() async {
    setState(() => _busy = true);
    try {
      await widget.wallet.requestCredential('MembershipCredential');
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add credential: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: CredentialList(credentials: widget.wallet.heldCredentials()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _requestMembership,
        icon: const Icon(Icons.add),
        label: const Text('Request membership'),
      ),
    );
  }
}
