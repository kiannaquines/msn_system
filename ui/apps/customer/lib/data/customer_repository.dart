import 'dart:async';

import 'package:mns_api_client/api_client.dart' as shared_api;
import 'package:mns_auth_session/auth_session.dart';
import 'package:mns_domain_models/domain_models.dart' as shared;

import '../models/customer_models.dart';

abstract interface class CustomerRepository {
  String? get realtimeToken;
  Future<CustomerProfile> login(String email, String password);
  Future<CustomerProfile> register(String name, String email, String password);
  Future<List<Store>> stores();
  Future<List<MenuItem>> menu(String storeId);
  Future<List<DeliveryAddress>> addresses();
  Future<DeliveryAddress> createAddress(String label, String address, {double? latitude, double? longitude});
  Future<CustomerOrder> placeOrder({
    required Store store,
    required List<CartLine> lines,
    required DeliveryAddress address,
  });
  Future<List<CustomerOrder>> orderHistory();
  Future<shared.DeliverySnapshot> deliverySnapshot(String deliveryId);
  Future<CustomerProfile?> restore();
  Future<void> submitFeedback(String orderId, int rating, String comment);
  Future<void> logout();
}

class DemoCustomerRepository implements CustomerRepository {
  final List<DeliveryAddress> _addresses = [const DeliveryAddress(id: 'home', label: 'Home', address: 'Poblacion, Kabacan', latitude: 7.1066, longitude: 124.8292)];
  @override
  String? get realtimeToken => null;

  Future<void> _delay() => Future<void>.delayed(const Duration(milliseconds: 350));

  @override
  Future<CustomerProfile> login(String email, String password) async {
    await _delay();
    return CustomerProfile(name: 'Alex Customer', email: email.trim());
  }

  @override
  Future<CustomerProfile> register(String name, String email, String password) async {
    await _delay();
    return CustomerProfile(name: name.trim(), email: email.trim());
  }

  @override
  Future<CustomerProfile?> restore() async => null;

  @override
  Future<List<Store>> stores() async {
    await _delay();
    return const [
      Store(id: 'store-1', name: 'M&S Kitchen', subtitle: 'Filipino comfort food made fresh', categories: ['Popular', 'Rice Meals', 'Drinks'], rating: 4.8, etaMinutes: 28),
      Store(id: 'store-2', name: 'M&S Quick Bites', subtitle: 'Snacks, sandwiches, and coolers', categories: ['Snacks', 'Sandwiches', 'Drinks'], rating: 4.6, etaMinutes: 20),
    ];
  }

  @override
  Future<List<MenuItem>> menu(String storeId) async {
    await _delay();
    return [
      MenuItem(id: '$storeId-1', storeId: storeId, name: 'Chicken Inasal', description: 'Char-grilled chicken, garlic rice, and atchara', category: 'Popular', price: 189),
      MenuItem(id: '$storeId-2', storeId: storeId, name: 'Beef Tapa Bowl', description: 'Tender tapa with egg and seasoned rice', category: 'Rice Meals', price: 199),
      MenuItem(id: '$storeId-3', storeId: storeId, name: 'Crispy Chicken Sandwich', description: 'Crispy fillet, fresh slaw, and house sauce', category: 'Sandwiches', price: 169),
      MenuItem(id: '$storeId-4', storeId: storeId, name: 'Calamansi Cooler', description: 'Fresh calamansi with honey and ice', category: 'Drinks', price: 69),
    ];
  }

  @override
  Future<List<DeliveryAddress>> addresses() async {
    await _delay();
    return List.unmodifiable(_addresses);
  }

  @override
  Future<DeliveryAddress> createAddress(String label, String address, {double? latitude, double? longitude}) async {
    await _delay();
    final created = DeliveryAddress(id: 'address-${_addresses.length + 1}', label: label, address: address, latitude: latitude, longitude: longitude);
    _addresses.add(created);
    return created;
  }

  @override
  Future<CustomerOrder> placeOrder({required Store store, required List<CartLine> lines, required DeliveryAddress address}) async {
    await _delay();
    return CustomerOrder(
      id: 'MNS-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      store: store,
      lines: List.unmodifiable(lines),
      address: address,
      stage: OrderStage.onTheWay,
      createdAt: DateTime.now(),
      deliveryFee: 49,
      etaMinutes: 18,
      deliveryId: 'delivery-demo',
      riderName: 'Miguel R.',
    );
  }

  @override
  Future<List<CustomerOrder>> orderHistory() async {
    await _delay();
    return [
      CustomerOrder(
        id: 'MNS-24017',
        store: const Store(id: 'store-1', name: 'M&S Kitchen', subtitle: '', categories: [], rating: 4.8, etaMinutes: 28),
        lines: const [],
        address: const DeliveryAddress(id: 'home', label: 'Home', address: 'Poblacion, Kabacan', latitude: 7.1066, longitude: 124.8292),
        stage: OrderStage.delivered,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        deliveryFee: 49,
        etaMinutes: 0,
        deliveryId: 'delivery-history',
        riderName: 'Ana P.',
      ),
    ];
  }

  @override
  Future<void> submitFeedback(String orderId, int rating, String comment) => _delay();

  @override
  Future<shared.DeliverySnapshot> deliverySnapshot(String deliveryId) async => shared.DeliverySnapshot(id: deliveryId, orderId: 'demo-order', status: shared.OrderStatus.onTheWay, latitude: 7.1066, longitude: 124.8292, etaMinutes: 12, lastLocationAt: DateTime.now(), destinationLatitude: 7.1100, destinationLongitude: 124.8300);

  @override
  Future<void> logout() async {}
}

class ApiCustomerRepository implements CustomerRepository {
  ApiCustomerRepository(String baseUrl) : _api = shared_api.ApiClient(baseUrl: baseUrl) {
    _session = AuthSession(_api);
  }
  final shared_api.ApiClient _api;
  late final AuthSession _session;

  @override
  String? get realtimeToken => _api.accessToken;

  @override
  Future<CustomerProfile> login(String email, String password) async {
    final tokens = await _api.login(email.trim(), password);
    if (tokens.role != shared.UserRole.customer) throw const shared_api.ApiException(403, 'Customer access required');
    await _session.apply(tokens);
    return CustomerProfile(name: email.split('@').first, email: email.trim());
  }

  @override
  Future<CustomerProfile> register(String name, String email, String password) async {
    final tokens = await _api.register(name: name.trim(), email: email.trim(), password: password);
    if (tokens.role != shared.UserRole.customer) throw const shared_api.ApiException(403, 'Customer access required');
    await _session.apply(tokens);
    return CustomerProfile(name: name.trim(), email: email.trim());
  }

  @override
  Future<CustomerProfile?> restore() async {
    if (!await _session.restore()) return null;
    if (_session.role != shared.UserRole.customer) {
      await _session.logout();
      return null;
    }
    try {
      final user = await _api.me();
      return CustomerProfile(name: user['full_name'] as String, email: user['email'] as String);
    } catch (_) {
      await _session.logout();
      rethrow;
    }
  }

  @override
  Future<List<Store>> stores() async => (await _api.listStores())
      .map((store) => Store(id: store.id, name: store.name, subtitle: store.description, categories: const ['Popular', 'Meals', 'Drinks'], rating: 4.8, etaMinutes: 30))
      .toList();

  @override
  Future<List<MenuItem>> menu(String storeId) async => (await _api.listMenuItems(storeId))
      .map((item) => MenuItem(id: item.id, storeId: item.storeId, name: item.name, description: item.description, category: 'Menu', price: item.price, available: item.available))
      .toList();

  @override
  Future<List<DeliveryAddress>> addresses() async => (await _api.listAddresses())
      .map((address) => DeliveryAddress(id: address.id, label: address.label, address: address.line1, latitude: address.latitude, longitude: address.longitude))
      .toList();

  @override
  Future<DeliveryAddress> createAddress(String label, String address, {double? latitude, double? longitude}) async {
    if (latitude == null || longitude == null) throw const shared_api.ApiException(422, 'A delivery location is required');
    final created = await _api.createAddress(label: label, line1: address, latitude: latitude, longitude: longitude);
    return DeliveryAddress(id: created.id, label: created.label, address: created.line1, latitude: created.latitude, longitude: created.longitude);
  }

  @override
  Future<CustomerOrder> placeOrder({required Store store, required List<CartLine> lines, required DeliveryAddress address}) async {
    var addressId = address.id;
    if (addressId == null) {
      if (address.latitude == null || address.longitude == null) throw const shared_api.ApiException(422, 'A delivery location is required');
      final created = await _api.createAddress(label: address.label, line1: address.address, latitude: address.latitude!, longitude: address.longitude!);
      addressId = created.id;
    }
    final order = await _api.createOrder(
      storeId: store.id,
      addressId: addressId,
      lines: lines.map((line) => shared.CartLine(item: shared.MenuItem(id: line.item.id, storeId: line.item.storeId, name: line.item.name, price: line.item.price), quantity: line.quantity)).toList(),
      idempotencyKey: 'customer-${DateTime.now().microsecondsSinceEpoch}',
    );
    return CustomerOrder(
      id: order.id,
      store: store,
      lines: List.unmodifiable(lines),
      address: DeliveryAddress(id: addressId, label: address.label, address: address.address, latitude: address.latitude, longitude: address.longitude),
      stage: _stage(order.status),
      createdAt: order.createdAt ?? DateTime.now(),
      deliveryFee: order.deliveryFee,
      etaMinutes: 30,
      deliveryId: order.deliveryId,
      subtotalAmount: order.subtotal,
      totalAmount: order.total,
    );
  }

  @override
  Future<List<CustomerOrder>> orderHistory() async => (await _api.listOrders()).map((order) {
        final store = Store(id: '', name: order.storeName.isEmpty ? 'M&S Store' : order.storeName, subtitle: '', categories: const [], rating: 0, etaMinutes: 0);
        final lines = order.items.map((line) => CartLine(item: MenuItem(id: line.menuItemId, storeId: '', name: line.name, description: '', category: 'Order item', price: line.unitPrice), quantity: line.quantity)).toList();
        return CustomerOrder(
          id: order.id,
          store: store,
          lines: lines,
          address: const DeliveryAddress(label: 'Delivery address', address: 'See order details'),
          stage: _stage(order.status),
          createdAt: order.createdAt ?? DateTime.now(),
          deliveryFee: order.deliveryFee,
          etaMinutes: 0,
          deliveryId: order.deliveryId,
          riderName: order.riderName,
          subtotalAmount: order.subtotal,
          totalAmount: order.total,
        );
      }).toList();

  @override
  Future<shared.DeliverySnapshot> deliverySnapshot(String deliveryId) => _api.getDelivery(deliveryId);

  @override
  Future<void> submitFeedback(String orderId, int rating, String comment) {
    return _api.submitFeedback(orderId, rating: rating, comment: comment.trim().isEmpty ? null : comment.trim());
  }

  @override
  Future<void> logout() => _session.logout();

  OrderStage _stage(shared.OrderStatus status) => switch (status) {
        shared.OrderStatus.pending => OrderStage.pending,
        shared.OrderStatus.confirmed => OrderStage.confirmed,
        shared.OrderStatus.assigned => OrderStage.assigned,
        shared.OrderStatus.pickedUp => OrderStage.pickedUp,
        shared.OrderStatus.onTheWay => OrderStage.onTheWay,
        shared.OrderStatus.delivered => OrderStage.delivered,
        shared.OrderStatus.cancelled => OrderStage.cancelled,
      };

  void close() {
    _session.dispose();
    _api.close();
  }
}
