import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mns_customer/src/customer_app.dart';

void main() {
  testWidgets('shows customer sign-in screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CustomerApp()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('New to M&S? Create an account'), findsOneWidget);
  });
}
