import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/customer_repository.dart';
import '../models/customer_models.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  const demoMode = bool.fromEnvironment('DEMO_MODE');
  if (demoMode) return DemoCustomerRepository();
  final repository = ApiCustomerRepository(baseUrl.isEmpty ? 'http://configuration.invalid' : baseUrl);
  ref.onDispose(repository.close);
  return repository;
});

class SessionState {
  const SessionState({this.profile, this.loading = false, this.error});
  final CustomerProfile? profile;
  final bool loading;
  final String? error;
  bool get authenticated => profile != null;
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._repository) : super(const SessionState()) {
    _restore();
  }
  final CustomerRepository _repository;

  Future<void> _restore() async {
    try {
      final profile = await _repository.restore();
      state = SessionState(profile: profile);
    } catch (_) {
      state = const SessionState();
    }
  }

  Future<bool> login(String email, String password) async {
    state = const SessionState(loading: true);
    try {
      final profile = await _repository.login(email, password);
      state = SessionState(profile: profile);
      return true;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      state = SessionState(error: message.isNotEmpty ? message : 'Unable to sign in. Please check your credentials or connection.');
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = const SessionState(loading: true);
    try {
      final profile = await _repository.register(name, email, password);
      state = SessionState(profile: profile);
      return true;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
      state = SessionState(error: message.isNotEmpty ? message : 'Unable to create your account.');
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const SessionState();
  }
}

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref.watch(customerRepositoryProvider));
});

final storesProvider = FutureProvider<List<Store>>((ref) => ref.watch(customerRepositoryProvider).stores());
final menuProvider = FutureProvider.family<List<MenuItem>, String>((ref, id) => ref.watch(customerRepositoryProvider).menu(id));
class AddressesController extends StateNotifier<AsyncValue<List<DeliveryAddress>>> {
  AddressesController(this._repository) : super(const AsyncValue.loading()) {
    _load();
  }
  final CustomerRepository _repository;

  Future<void> _load() async {
    try {
      final items = await _repository.addresses();
      if (mounted) {
        state = AsyncValue.data(items);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> load() async {
    if (mounted) {
      state = const AsyncValue.loading();
    }
    await _load();
  }

  Future<bool> deleteAddress(String id) async {
    final current = state.value ?? [];
    if (mounted) {
      state = AsyncValue.data(current.where((a) => a.id != id).toList());
    }
    try {
      await _repository.deleteAddress(id);
      return true;
    } catch (_) {
      if (mounted) {
        state = AsyncValue.data(current);
      }
      return false;
    }
  }
}

final addressesProvider = StateNotifierProvider<AddressesController, AsyncValue<List<DeliveryAddress>>>((ref) {
  return AddressesController(ref.watch(customerRepositoryProvider));
});

class CartState {
  const CartState({this.store, this.lines = const []});
  final Store? store;
  final List<CartLine> lines;
  int get count => lines.fold(0, (sum, line) => sum + line.quantity);
  double get subtotal => lines.fold(0, (sum, line) => sum + line.total);
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

  void add(Store store, MenuItem item) {
    final sameStore = state.store == null || state.store!.id == store.id;
    final current = sameStore ? [...state.lines] : <CartLine>[];
    final index = current.indexWhere((line) => line.item.id == item.id);
    if (index < 0) {
      current.add(CartLine(item: item, quantity: 1));
    } else {
      current[index] = current[index].copyWith(quantity: current[index].quantity + 1);
    }
    state = CartState(store: store, lines: current);
  }

  void setQuantity(String id, int quantity) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.item.id == id);
    if (index < 0) return;
    if (quantity <= 0) {
      lines.removeAt(index);
    } else {
      lines[index] = lines[index].copyWith(quantity: quantity);
    }
    state = CartState(store: lines.isEmpty ? null : state.store, lines: lines);
  }

  void clear() => state = const CartState();
}

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) => CartController());

class OrdersController extends StateNotifier<List<CustomerOrder>> {
  OrdersController(this._repository) : super(const []);
  final CustomerRepository _repository;

  Future<void> load() async {
    try {
      state = await _repository.orderHistory();
    } catch (_) {
      // Keep the current list visible; the user can still place a new order.
    }
  }

  Future<CustomerOrder?> place(CartState cart, DeliveryAddress address) async {
    if (cart.store == null || cart.lines.isEmpty) return null;
    final order = await _repository.placeOrder(store: cart.store!, lines: cart.lines, address: address);
    state = [order, ...state];
    return order;
  }

}

final ordersProvider = StateNotifierProvider<OrdersController, List<CustomerOrder>>((ref) {
  return OrdersController(ref.watch(customerRepositoryProvider));
});
