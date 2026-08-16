import 'package:mns_domain_models/domain_models.dart';
import 'package:test/test.dart';

void main() {
  test('API order state names round-trip', () {
    for (final status in OrderStatus.values) {
      expect(OrderStatus.fromApi(status.apiValue), status);
    }
  });
}
