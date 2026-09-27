import 'package:credentials_app/credentials_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_issuer_client.dart';
import 'fixtures.dart';

void main() {
  testWidgets('shows an empty wallet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CredentialList(credentials: [])),
      ),
    );
    expect(find.text('No credentials yet'), findsOneWidget);
  });

  testWidgets('lists held credentials by type and issuer', (tester) async {
    final credential = HeldCredential.fromIssuance(membershipIssuance());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CredentialList(credentials: [credential])),
      ),
    );
    expect(find.text('MembershipCredential'), findsOneWidget);
    expect(find.text(issuerDid), findsOneWidget);
  });

  testWidgets('requesting a membership adds it to the list', (tester) async {
    final wallet = WalletService(issuer: FakeIssuerClient());
    await tester.pumpWidget(MaterialApp(home: WalletScreen(wallet: wallet)));
    expect(find.text('No credentials yet'), findsOneWidget);

    await tester.tap(find.text('Request membership'));
    await tester.pumpAndSettle();

    expect(find.text('MembershipCredential'), findsOneWidget);
    expect(wallet.heldCredentials(), hasLength(1));
  });

  testWidgets('a failed request shows an error', (tester) async {
    final wallet = WalletService(
      issuer: FakeIssuerClient(subjectOverride: 'did:key:z6MkSomeoneElse'),
    );
    await tester.pumpWidget(MaterialApp(home: WalletScreen(wallet: wallet)));

    await tester.tap(find.text('Request membership'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not add credential'), findsOneWidget);
    expect(find.text('No credentials yet'), findsOneWidget);
  });
}
