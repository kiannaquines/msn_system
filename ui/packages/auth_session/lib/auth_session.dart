import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mns_api_client/api_client.dart';
import 'package:mns_domain_models/domain_models.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this.api, {FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage() {
    api.tokenRefresher = _refreshAccessToken;
  }
  final ApiClient api;
  final FlutterSecureStorage _storage;
  UserRole? role;
  bool get authenticated => api.accessToken != null;

  Future<bool> restore() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;
    try {
      await apply(await api.refresh(refreshToken));
      return true;
    } catch (_) {
      await _clearLocal();
      return false;
    }
  }

  Future<void> apply(AuthTokens tokens) async {
    api.accessToken = tokens.accessToken;
    role = tokens.role;
    await _storage.write(key: 'access_token', value: tokens.accessToken);
    await _storage.write(key: 'refresh_token', value: tokens.refreshToken);
    await _storage.write(key: 'role', value: tokens.role.name);
    notifyListeners();
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return null;
    try {
      final tokens = await api.refresh(refreshToken);
      await apply(tokens);
      return tokens.accessToken;
    } catch (_) {
      await _clearLocal();
      return null;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken != null && api.accessToken != null) {
      try {
        await api.logout(refreshToken);
      } catch (_) {
        // Local sign-out must still complete when the network is unavailable.
      }
    }
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    api.accessToken = null;
    role = null;
    await _storage.deleteAll();
    notifyListeners();
  }
}
