import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mns_admin/main.dart';

void main() {
  testWidgets('shows administrator login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AdminApp()));
    expect(find.text('Operations portal'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
