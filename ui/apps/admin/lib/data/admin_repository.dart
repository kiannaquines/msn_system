import 'package:mns_api_client/api_client.dart';
import 'package:mns_auth_session/auth_session.dart';
import 'package:mns_domain_models/domain_models.dart' as shared;

import '../models/admin_models.dart';

class AdminSnapshot {
  const AdminSnapshot({required this.stores, required this.orders, required this.riders, required this.deliveries, required this.audit, required this.feedback, required this.report});
  final List<AdminStore> stores;
  final List<AdminOrder> orders;
  final List<AdminRider> riders;
  final List<LiveDelivery> deliveries;
  final List<AuditEntry> audit;
  final List<FeedbackEntry> feedback;
  final Map<String, num> report;
}

abstract interface class AdminRepository {
  Future<bool> restore();
  Future<void> login(String email, String password);
  Future<void> logout();
  Future<AdminSnapshot> load();
  Future<AdminStore> saveStore(AdminStore store, {required bool create});
  Future<void> deleteStore(AdminStore store, String reason);
  Future<AdminMenuItem> saveMenuItem(String storeId, AdminMenuItem item, {required bool create});
  Future<void> deleteMenuItem(AdminMenuItem item, String reason);
  Future<AdminRider> createRider({required String name, required String email, required String password, required String phone});
  Future<void> assign(String orderId, String riderId, String reason);
  Future<void> cancel(String orderId, String reason);
}

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl({String? baseUrl, required this.demoMode}) : _api = demoMode ? null : ApiClient(baseUrl: baseUrl ?? '') {
    if (_api != null) _session = AuthSession(_api!);
  }
  final bool demoMode;
  final ApiClient? _api;
  AuthSession? _session;

  @override
  Future<bool> restore() async {
    final api = _api;
    if (api == null) return false;
    if (!await _session!.restore()) return false;
    if (_session!.role != shared.UserRole.admin) {
      await _session!.logout();
      return false;
    }
    try {
      await api.me();
      return true;
    } catch (_) {
      await _session!.logout();
      return false;
    }
  }

  @override
  Future<void> login(String email, String password) async {
    if (!demoMode && _api!.baseUrl.isEmpty) throw StateError('API_BASE_URL is required unless DEMO_MODE=true');
    final api = _api;
    if (api == null) return;
    final tokens = await api.login(email.trim(), password);
    if (tokens.role != shared.UserRole.admin) throw const ApiException(403, 'Administrator access required');
    await _session!.apply(tokens);
  }

  @override
  Future<void> logout() async {
    final session = _session;
    if (session != null) await session.logout();
  }

  @override
  Future<AdminSnapshot> load() async {
    final api = _api;
    if (api == null) return _demo();
    final results = await Future.wait([api.listStores(), api.listOrders(), api.listRidersRaw(), api.listDeliveriesRaw(), api.listFeedbackRaw(), api.listAuditRaw(), api.reportSummary()]);
    final sourceStores = results[0] as List<shared.Store>;
    final stores = <AdminStore>[];
    for (final store in sourceStores) {
      final menu = await api.listMenuItems(store.id);
      stores.add(AdminStore(id: store.id, name: store.name, description: store.description, items: menu.map((item) => AdminMenuItem(id: item.id, name: item.name, category: 'Menu', price: item.price, available: item.available)).toList()));
    }
    final orders = (results[1] as List<shared.OrderSummary>).map((order) => AdminOrder(id: order.id, customer: 'Customer', store: order.storeName, total: order.total, status: _status(order.status), createdAt: order.createdAt ?? DateTime.now(), codPaid: order.paymentStatus == shared.PaymentStatus.paid)).toList();
    final riders = (results[2] as List<shared.Json>).map((json) => AdminRider(id: json['id'] as String, name: (json['name'] ?? json['full_name']) as String, phone: json['phone'] as String? ?? '', status: AdminRiderStatus.values.byName((json['status'] ?? json['rider_status'] ?? 'offline') as String), activeDelivery: json['active_delivery_id'] as String?)).toList();
    final riderNames = {for (final rider in riders) rider.id: rider.name};
    final deliveries = (results[3] as List<shared.Json>).map((json) => LiveDelivery(id: json['id'] as String, orderId: json['order_id'] as String, rider: json['rider_name'] as String? ?? riderNames[json['rider_id']] ?? 'Unassigned', customer: json['customer_name'] as String? ?? 'Customer', status: _status(shared.OrderStatus.fromApi(json['status'] as String)), updatedAt: DateTime.tryParse(json['last_location_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0), latitude: (json['latitude'] as num?)?.toDouble() ?? 0, longitude: (json['longitude'] as num?)?.toDouble() ?? 0)).toList();
    final feedback = (results[4] as List<shared.Json>).map((json) => FeedbackEntry(orderId: json['order_id'] as String, customer: json['customer_name'] as String? ?? 'Customer', rating: json['rating'] as int, comment: json['comment'] as String? ?? '', createdAt: DateTime.parse(json['created_at'] as String))).toList();
    final audit = (results[5] as List<shared.Json>).map((json) => AuditEntry(action: json['action'] as String, actor: json['actor_name'] as String? ?? 'System', target: json['target_id'] as String, reason: json['reason'] as String? ?? '', createdAt: DateTime.parse(json['created_at'] as String))).toList();
    final reportJson = results[6] as shared.Json;
    final report = reportJson.map((key, value) => MapEntry(key, value as num));
    return AdminSnapshot(stores: stores, orders: orders, riders: riders, deliveries: deliveries, audit: audit, feedback: feedback, report: report);
  }

  @override
  Future<AdminStore> saveStore(AdminStore store, {required bool create}) async {
    final api = _api;
    if (api == null) return store;
    final saved = create
        ? await api.createStore(name: store.name, description: store.description, latitude: 7.0731, longitude: 125.6128)
        : await api.updateStore(store.id, {'name': store.name, 'description': store.description, 'is_active': store.available});
    return AdminStore(id: saved.id, name: saved.name, description: saved.description, available: store.available, items: store.items);
  }

  @override
  Future<void> deleteStore(AdminStore store, String reason) async {
    final api = _api;
    if (api != null) await api.deleteStore(store.id, reason);
  }

  @override
  Future<AdminMenuItem> saveMenuItem(String storeId, AdminMenuItem item, {required bool create}) async {
    final api = _api;
    if (api == null) return item;
    final saved = create
        ? await api.createMenuItem(storeId, category: item.category, name: item.name, description: '', price: item.price)
        : await api.updateMenuItem(item.id, {'category': item.category, 'name': item.name, 'price': item.price, 'is_available': item.available});
    return AdminMenuItem(id: saved.id, name: saved.name, category: item.category, price: saved.price, available: saved.available);
  }

  @override
  Future<void> deleteMenuItem(AdminMenuItem item, String reason) async {
    final api = _api;
    if (api != null) await api.deleteMenuItem(item.id, reason);
  }

  @override
  Future<AdminRider> createRider({required String name, required String email, required String password, required String phone}) async {
    final api = _api;
    if (api == null) return AdminRider(id: 'rider-${DateTime.now().millisecondsSinceEpoch}', name: name, phone: phone, status: AdminRiderStatus.offline);
    final json = await api.createRider(name: name, email: email, password: password, phone: phone);
    return AdminRider(id: json['id'] as String, name: (json['name'] ?? json['full_name']) as String, phone: json['phone'] as String? ?? '', status: AdminRiderStatus.offline);
  }

  @override
  Future<void> assign(String orderId, String riderId, String reason) async {
    final api = _api;
    if (api == null) return;
    final order = (await api.listOrders()).firstWhere((item) => item.id == orderId);
    if (order.status == shared.OrderStatus.pending) await api.updateOrderStatus(orderId, shared.OrderStatus.confirmed, idempotencyKey: _key('confirm', orderId), reason: reason);
    await api.assignRider(orderId, riderId);
  }

  @override
  Future<void> cancel(String orderId, String reason) async {
    final api = _api;
    if (api != null) await api.updateOrderStatus(orderId, shared.OrderStatus.cancelled, idempotencyKey: _key('cancel', orderId), reason: reason);
  }

  String _key(String action, String id) => 'admin-$action-$id-${DateTime.now().microsecondsSinceEpoch}';

  AdminOrderStatus _status(shared.OrderStatus status) => switch (status) {
        shared.OrderStatus.pending => AdminOrderStatus.pending,
        shared.OrderStatus.confirmed => AdminOrderStatus.confirmed,
        shared.OrderStatus.assigned => AdminOrderStatus.assigned,
        shared.OrderStatus.pickedUp => AdminOrderStatus.pickedUp,
        shared.OrderStatus.onTheWay => AdminOrderStatus.onTheWay,
        shared.OrderStatus.delivered => AdminOrderStatus.delivered,
        shared.OrderStatus.cancelled => AdminOrderStatus.cancelled,
      };

  AdminSnapshot _demo() {
    final now = DateTime.now();
    return AdminSnapshot(
      stores: const [
        AdminStore(id: 's1', name: 'M&S Kitchen', description: 'Filipino comfort food', items: [AdminMenuItem(id: 'm1', name: 'Chicken Inasal', category: 'Rice Meals', price: 189), AdminMenuItem(id: 'm2', name: 'Calamansi Cooler', category: 'Drinks', price: 69)]),
        AdminStore(id: 's2', name: 'M&S Quick Bites', description: 'Snacks and sandwiches'),
      ],
      orders: [
        AdminOrder(id: 'MNS-30241', customer: 'Alex D.', store: 'M&S Kitchen', total: 427, status: AdminOrderStatus.pending, createdAt: now.subtract(const Duration(minutes: 8))),
        AdminOrder(id: 'MNS-30240', customer: 'Jamie C.', store: 'M&S Quick Bites', total: 318, status: AdminOrderStatus.onTheWay, createdAt: now.subtract(const Duration(minutes: 31)), rider: 'Miguel R.'),
        AdminOrder(id: 'MNS-30219', customer: 'Sam P.', store: 'M&S Kitchen', total: 506, status: AdminOrderStatus.delivered, createdAt: now.subtract(const Duration(hours: 3)), rider: 'Ana P.', codPaid: true),
      ],
      riders: const [AdminRider(id: 'r1', name: 'Ana P.', phone: '0917 555 0132', status: AdminRiderStatus.available), AdminRider(id: 'r2', name: 'Miguel R.', phone: '0917 555 0188', status: AdminRiderStatus.busy, activeDelivery: 'DEL-201')],
      deliveries: [
        LiveDelivery(id: 'DEL-201', orderId: 'MNS-30240', rider: 'Miguel R.', customer: 'Jamie C.', status: AdminOrderStatus.onTheWay, updatedAt: now.subtract(const Duration(seconds: 12)), latitude: 7.0731, longitude: 125.6128),
        LiveDelivery(id: 'DEL-199', orderId: 'MNS-30232', rider: 'Carlo M.', customer: 'Bea S.', status: AdminOrderStatus.assigned, updatedAt: now.subtract(const Duration(minutes: 2)), latitude: 7.081, longitude: 125.605),
      ],
      audit: [AuditEntry(action: 'Order assigned', actor: 'Admin User', target: 'MNS-30240', reason: 'Nearest available rider', createdAt: now.subtract(const Duration(minutes: 27)))],
      feedback: [FeedbackEntry(orderId: 'MNS-30219', customer: 'Sam P.', rating: 5, comment: 'Fast delivery and the food arrived warm.', createdAt: now.subtract(const Duration(hours: 2)))],
      report: const {'orders': 3, 'delivered': 1, 'cancelled': 0, 'cod_sales': 506},
    );
  }

  void close() {
    _session?.dispose();
    _api?.close();
  }
}
