import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mns_customer/src/customer_app.dart';

void main() {
  testWidgets('shows customer sign-in screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CustomerApp()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    // Toggle link is rendered as Text.rich with separate spans
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && w.data == null && w.textSpan != null && w.textSpan!.toPlainText().contains('Create an account'),
      ),
      findsOneWidget,
    );
  });
}
