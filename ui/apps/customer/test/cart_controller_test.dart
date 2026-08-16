import 'package:flutter_test/flutter_test.dart';
import 'package:mns_customer/models/customer_models.dart';
import 'package:mns_customer/state/customer_state.dart';

void main() {
  const store = Store(id: 's1', name: 'Store', subtitle: '', categories: [], rating: 5, etaMinutes: 10);
  const item = MenuItem(id: 'i1', storeId: 's1', name: 'Meal', description: '', category: 'Popular', price: 100);

  test('cart adds items and calculates totals', () {
    final controller = CartController();
    controller.add(store, item);
    controller.add(store, item);

    expect(controller.state.count, 2);
    expect(controller.state.subtotal, 200);
  });

  test('setting the last line to zero clears the store', () {
    final controller = CartController();
    controller.add(store, item);
    controller.setQuantity(item.id, 0);

    expect(controller.state.lines, isEmpty);
    expect(controller.state.store, isNull);
  });
}
