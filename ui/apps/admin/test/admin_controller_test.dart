import 'package:flutter_test/flutter_test.dart';
import 'package:mns_admin/data/admin_repository.dart';
import 'package:mns_admin/models/admin_models.dart';
import 'package:mns_admin/state/admin_state.dart';

void main() {
  test('production mode rejects missing API configuration', () async {
    final controller = AdminController(AdminRepositoryImpl(demoMode: false));
    expect(await controller.login('admin@mns.test', 'password123'), isFalse);
    expect(controller.state.error, contains('API_BASE_URL'));
  });

  test('assignment updates an order and records an audit entry', () async {
    final controller = AdminController(AdminRepositoryImpl(demoMode: true));
    expect(await controller.login('admin@mns.demo', 'password123'), isTrue);
    final before = controller.state.snapshot!;
    final order = before.orders.firstWhere((item) => item.status == AdminOrderStatus.pending);
    final rider = before.riders.firstWhere((item) => item.status == AdminRiderStatus.available);

    await controller.assign(order.id, rider, 'Nearest rider');

    final after = controller.state.snapshot!;
    expect(after.orders.firstWhere((item) => item.id == order.id).rider, rider.name);
    expect(after.audit.first.target, order.id);
    expect(after.audit.first.reason, 'Nearest rider');
  });

  test('catalog mutations preserve other stores', () async {
    final controller = AdminController(AdminRepositoryImpl(demoMode: true));
    await controller.login('admin@mns.demo', 'password123');
    final before = controller.state.snapshot!;
    final store = before.stores.first;

    await controller.saveMenuItem(store.id, const AdminMenuItem(id: 'new', name: 'New Meal', category: 'Meals', price: 150));

    final after = controller.state.snapshot!;
    expect(after.stores, hasLength(before.stores.length));
    expect(after.stores.firstWhere((item) => item.id == store.id).items.any((item) => item.id == 'new'), isTrue);
  });
}
