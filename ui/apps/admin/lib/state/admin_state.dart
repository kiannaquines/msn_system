import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_repository.dart';
import '../models/admin_models.dart';

final adminRepositoryProvider = Provider<AdminRepositoryImpl>((ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  const demoMode = bool.fromEnvironment('DEMO_MODE');
  final repository = AdminRepositoryImpl(baseUrl: baseUrl, demoMode: demoMode);
  ref.onDispose(repository.close);
  return repository;
});

class AdminState {
  const AdminState({this.authenticated = false, this.loading = false, this.error, this.snapshot});
  final bool authenticated;
  final bool loading;
  final String? error;
  final AdminSnapshot? snapshot;
}

class AdminController extends StateNotifier<AdminState> {
  AdminController(this._repository) : super(const AdminState());
  final AdminRepository _repository;

  Future<void> restore() async {
    state = const AdminState(loading: true);
    if (!await _repository.restore()) {
      state = const AdminState();
      return;
    }
    try {
      state = AdminState(authenticated: true, snapshot: await _repository.load());
    } catch (_) {
      await _repository.logout();
      state = const AdminState(error: 'Unable to restore the administrator session.');
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AdminState(loading: true);
    try {
      await _repository.login(email, password);
      final snapshot = await _repository.load();
      state = AdminState(authenticated: true, snapshot: snapshot);
      return true;
    } catch (error) {
      state = AdminState(error: error.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AdminState();
  }

  Future<void> refreshDeliveries() async {
    if (!state.authenticated || state.snapshot == null) return;
    try {
      final snapshot = await _repository.load();
      state = AdminState(authenticated: true, snapshot: snapshot);
    } catch (_) {
      // Retain existing snapshot if background telemetry poll experiences network blip
    }
  }

  Future<void> saveStore(AdminStore store) async {
    final data = state.snapshot!;
    final create = !data.stores.any((item) => item.id == store.id);
    final saved = await _repository.saveStore(store, create: create);
    final stores = [...data.stores];
    final index = stores.indexWhere((item) => item.id == store.id);
    if (index < 0) { stores.add(saved); } else { stores[index] = saved; }
    _set(data, stores: stores, audit: [_audit('Store updated', saved.name, 'Catalog maintenance'), ...data.audit]);
  }

  Future<void> removeStore(AdminStore store, String reason) async {
    final data = state.snapshot!;
    await _repository.deleteStore(store, reason);
    _set(data, stores: data.stores.where((item) => item.id != store.id).toList(), audit: [_audit('Store removed', store.name, reason), ...data.audit]);
  }

  Future<void> saveMenuItem(String storeId, AdminMenuItem item) async {
    final data = state.snapshot!;
    final store = data.stores.firstWhere((entry) => entry.id == storeId);
    final create = !store.items.any((entry) => entry.id == item.id);
    final saved = await _repository.saveMenuItem(storeId, item, create: create);
    final stores = data.stores.map((store) {
      if (store.id != storeId) return store;
      final items = [...store.items];
      final index = items.indexWhere((entry) => entry.id == item.id);
      if (index < 0) { items.add(saved); } else { items[index] = saved; }
      return store.copyWith(items: items);
    }).toList();
    _set(data, stores: stores, audit: [_audit('Menu item updated', saved.name, 'Catalog maintenance'), ...data.audit]);
  }

  Future<void> removeMenuItem(String storeId, AdminMenuItem item) async {
    final data = state.snapshot!;
    await _repository.deleteMenuItem(item, 'Catalog maintenance');
    final stores = data.stores.map((store) => store.id == storeId ? store.copyWith(items: store.items.where((entry) => entry.id != item.id).toList()) : store).toList();
    _set(data, stores: stores, audit: [_audit('Menu item removed', item.name, 'Catalog maintenance'), ...data.audit]);
  }

  Future<void> saveRider({required String name, required String email, required String password, required String phone}) async {
    final data = state.snapshot!;
    final rider = await _repository.createRider(name: name, email: email, password: password, phone: phone);
    final riders = [...data.riders, rider];
    state = AdminState(authenticated: true, snapshot: AdminSnapshot(stores: data.stores, orders: data.orders, riders: riders, deliveries: data.deliveries, audit: [_audit('Rider created', rider.name, 'Operations staffing'), ...data.audit], feedback: data.feedback, report: data.report));
  }

  Future<void> updateRider(AdminRider rider, {required String name, required String phone, required AdminRiderStatus status}) async {
    final data = state.snapshot!;
    final updated = rider.copyWith(name: name, phone: phone, status: status);
    final riders = data.riders.map((r) => r.id == rider.id ? updated : r).toList();
    state = AdminState(
      authenticated: true,
      snapshot: AdminSnapshot(
        stores: data.stores,
        orders: data.orders,
        riders: riders,
        deliveries: data.deliveries,
        audit: [_audit('Rider updated', updated.name, 'Courier details update'), ...data.audit],
        feedback: data.feedback,
        report: data.report,
      ),
    );
  }

  Future<void> assign(String orderId, AdminRider rider, String reason) async {
    final data = state.snapshot!;
    await _repository.assign(orderId, rider.id, reason);
    final orders = data.orders.map((order) => order.id == orderId ? order.copyWith(status: AdminOrderStatus.assigned, rider: rider.name) : order).toList();
    _set(data, orders: orders, audit: [_audit('Order assigned', orderId, reason), ...data.audit]);
  }

  Future<void> cancel(String orderId, String reason) async {
    final data = state.snapshot!;
    await _repository.cancel(orderId, reason);
    final orders = data.orders.map((order) => order.id == orderId ? order.copyWith(status: AdminOrderStatus.cancelled) : order).toList();
    _set(data, orders: orders, audit: [_audit('Order cancelled', orderId, reason), ...data.audit]);
  }

  AuditEntry _audit(String action, String target, String reason) => AuditEntry(action: action, actor: 'Admin User', target: target, reason: reason, createdAt: DateTime.now());

  void _set(AdminSnapshot old, {List<AdminStore>? stores, List<AdminOrder>? orders, List<AuditEntry>? audit}) {
    state = AdminState(authenticated: true, snapshot: AdminSnapshot(stores: stores ?? old.stores, orders: orders ?? old.orders, riders: old.riders, deliveries: old.deliveries, audit: audit ?? old.audit, feedback: old.feedback, report: old.report));
  }
}

final adminProvider = StateNotifierProvider<AdminController, AdminState>((ref) => AdminController(ref.watch(adminRepositoryProvider)));
