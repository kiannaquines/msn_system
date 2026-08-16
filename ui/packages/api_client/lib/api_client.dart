import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mns_domain_models/domain_models.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken, required this.role});
  final String accessToken;
  final String refreshToken;
  final UserRole role;
  factory AuthTokens.fromJson(Json json) => AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        role: UserRole.values.byName(json['role'] as String),
      );
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final String baseUrl;
  final http.Client _http;
  String? accessToken;
  Future<String?> Function()? tokenRefresher;

  Map<String, String> _headers({String? idempotencyKey}) => {
        'content-type': 'application/json',
        if (accessToken != null) 'authorization': 'Bearer $accessToken',
        if (idempotencyKey != null) 'idempotency-key': idempotencyKey,
      };

  Future<dynamic> _send(String method, String path, {Object? body, String? idempotencyKey, bool allowRefresh = true}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))..headers.addAll(_headers(idempotencyKey: idempotencyKey));
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode == 401 && allowRefresh && tokenRefresher != null) {
      final refreshed = await tokenRefresher!();
      if (refreshed != null) return _send(method, path, body: body, idempotencyKey: idempotencyKey, allowRefresh: false);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['detail']?.toString() : null;
      throw ApiException(response.statusCode, message ?? 'Request failed');
    }
    return decoded;
  }

  Future<AuthTokens> login(String email, String password) async => AuthTokens.fromJson(
        await _send('POST', '/api/v1/auth/login', body: {'email': email, 'password': password}) as Json,
      );

  Future<AuthTokens> register({required String name, required String email, required String password, String? phone}) async => AuthTokens.fromJson(
        await _send('POST', '/api/v1/auth/register', body: {'name': name, 'email': email, 'password': password, if (phone != null) 'phone': phone}) as Json,
      );

  Future<AuthTokens> refresh(String refreshToken) async => AuthTokens.fromJson(
        await _send('POST', '/api/v1/auth/refresh', body: {'refresh_token': refreshToken}, allowRefresh: false) as Json,
      );

  Future<void> logout(String refreshToken) => _send('POST', '/api/v1/auth/logout', body: {'refresh_token': refreshToken}, allowRefresh: false);

  Future<Json> me() async => await _send('GET', '/api/v1/auth/me') as Json;

  Future<List<Store>> listStores() async => ((await _send('GET', '/api/v1/stores')) as List).map((value) => Store.fromJson(value as Json)).toList();

  Future<Store> createStore({required String name, required String description, required double latitude, required double longitude}) async => Store.fromJson(
        await _send('POST', '/api/v1/stores', body: {'name': name, 'description': description, 'latitude': latitude, 'longitude': longitude, 'is_active': true}) as Json,
      );

  Future<Store> updateStore(String storeId, Json changes) async => Store.fromJson(await _send('PATCH', '/api/v1/stores/$storeId', body: changes) as Json);

  Future<void> deleteStore(String storeId, String reason) => _send('DELETE', '/api/v1/stores/$storeId?reason=${Uri.encodeQueryComponent(reason)}');

  Future<List<MenuItem>> listMenuItems(String storeId) async => ((await _send('GET', '/api/v1/stores/$storeId/menu-items')) as List).map((value) => MenuItem.fromJson(value as Json)).toList();

  Future<MenuItem> createMenuItem(String storeId, {required String category, required String name, required String description, required double price}) async => MenuItem.fromJson(
        await _send('POST', '/api/v1/stores/$storeId/menu-items', body: {'category': category, 'name': name, 'description': description, 'price': price, 'is_available': true}) as Json,
      );

  Future<MenuItem> updateMenuItem(String itemId, Json changes) async => MenuItem.fromJson(await _send('PATCH', '/api/v1/menu-items/$itemId', body: changes) as Json);

  Future<void> deleteMenuItem(String itemId, String reason) => _send('DELETE', '/api/v1/menu-items/$itemId?reason=${Uri.encodeQueryComponent(reason)}');

  Future<List<CustomerAddress>> listAddresses() async => ((await _send('GET', '/api/v1/customers/me/addresses')) as List).map((value) => CustomerAddress.fromJson(value as Json)).toList();

  Future<CustomerAddress> createAddress({required String label, required String line1, required double latitude, required double longitude}) async => CustomerAddress.fromJson(
        await _send('POST', '/api/v1/customers/me/addresses', body: {'label': label, 'line1': line1, 'latitude': latitude, 'longitude': longitude}) as Json,
      );

  Future<List<OrderSummary>> listOrders() async => ((await _send('GET', '/api/v1/orders')) as List).map((value) => OrderSummary.fromJson(value as Json)).toList();

  Future<OrderSummary> createOrder({required String storeId, required String addressId, required List<CartLine> lines, String? notes, required String idempotencyKey}) async => OrderSummary.fromJson(
        await _send('POST', '/api/v1/orders', idempotencyKey: idempotencyKey, body: {
          'store_id': storeId,
          'delivery_address_id': addressId,
          'notes': notes,
          'items': lines.map((line) => {'menu_item_id': line.item.id, 'quantity': line.quantity}).toList(),
        }) as Json,
      );

  Future<DeliverySnapshot> getDelivery(String deliveryId) async => DeliverySnapshot.fromJson(await _send('GET', '/api/v1/deliveries/$deliveryId') as Json);

  Future<List<DeliverySnapshot>> listAssignedDeliveries() async => ((await _send('GET', '/api/v1/deliveries?assigned_to=me')) as List).map((value) => DeliverySnapshot.fromJson(value as Json)).toList();

  Future<List<Json>> listDeliveriesRaw() async => ((await _send('GET', '/api/v1/deliveries')) as List).cast<Json>();

  Future<List<Json>> listRidersRaw() async => ((await _send('GET', '/api/v1/riders')) as List).cast<Json>();

  Future<Json> createRider({required String name, required String email, required String password, String? phone}) async => await _send('POST', '/api/v1/riders', body: {'full_name': name, 'email': email, 'password': password, 'phone': phone, 'role': 'rider'}) as Json;

  Future<Json> assignRider(String orderId, String riderId) async => await _send('POST', '/api/v1/orders/$orderId/assign', body: {'rider_id': riderId}) as Json;

  Future<Json> updateOrderStatus(String orderId, OrderStatus status, {required String idempotencyKey, String? reason}) async => await _send('POST', '/api/v1/orders/$orderId/status', idempotencyKey: idempotencyKey, body: {'status': status.apiValue, 'reason': reason}) as Json;

  Future<Json> reportSummary() async => await _send('GET', '/api/v1/reports/summary') as Json;

  Future<List<Json>> listFeedbackRaw() async => ((await _send('GET', '/api/v1/feedback')) as List).cast<Json>();

  Future<List<Json>> listAuditRaw() async => ((await _send('GET', '/api/v1/audit')) as List).cast<Json>();

  Future<Json> authorizeMenuImageUpload({required String filename, required String contentType, required int sizeBytes}) async => await _send(
        'POST',
        '/api/v1/uploads/menu-images/authorize',
        body: {'filename': filename, 'content_type': contentType, 'size_bytes': sizeBytes},
      ) as Json;

  Future<Json> finalizeMenuImageUpload(String objectPath) async => await _send(
        'POST',
        '/api/v1/uploads/menu-images/finalize',
        body: {'object_path': objectPath},
      ) as Json;

  Future<void> registerDevice({required String token, required String platform}) =>
      _send('POST', '/api/v1/devices', body: {'token': token, 'platform': platform});

  Future<void> setRiderAvailability(RiderStatus status) => _send('PUT', '/api/v1/riders/me/availability', body: {'status': status.name});

  Future<void> updateDeliveryStatus(String deliveryId, OrderStatus status, String idempotencyKey) => _send('POST', '/api/v1/deliveries/$deliveryId/status', idempotencyKey: idempotencyKey, body: {'status': status.apiValue});

  Future<void> recordLocation(String deliveryId, {required double latitude, required double longitude, required double accuracyMeters, required DateTime recordedAt, required String idempotencyKey}) => _send('POST', '/api/v1/deliveries/$deliveryId/locations', idempotencyKey: idempotencyKey, body: {'latitude': latitude, 'longitude': longitude, 'accuracy_meters': accuracyMeters, 'recorded_at': recordedAt.toUtc().toIso8601String()});

  Future<void> confirmCod(String deliveryId, String idempotencyKey) => _send('POST', '/api/v1/deliveries/$deliveryId/confirm-cod', idempotencyKey: idempotencyKey);

  Future<void> submitFeedback(String orderId, {required int rating, String? comment}) => _send('POST', '/api/v1/orders/$orderId/feedback', body: {'rating': rating, 'comment': comment});

  void close() => _http.close();
}
