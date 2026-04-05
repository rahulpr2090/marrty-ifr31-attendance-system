// lib/features/auth/data/auth_repository.dart
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/auth_models.dart';

class AuthRepository {
  final _api = ApiClient.instance;

  /// Step 1: email + password → returns challenge or tokens
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _api.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Step 2: respond to auth challenge (MFA verify or setup)
  Future<Map<String, dynamic>> verifyMfa({
    required String session,
    required String code,
    required String challengeName,
  }) async {
    final res = await _api.post(ApiConstants.verifyMfa, data: {
      'session': session,
      'code': code,
      'challengeName': challengeName,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Force password change (NEW_PASSWORD_REQUIRED challenge)
  Future<Map<String, dynamic>> changePassword({
    required String email,
    required String session,
    required String newPassword,
  }) async {
    final res = await _api.post(ApiConstants.changePassword, data: {
      'email': email,
      'session': session,
      'newPassword': newPassword,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Get current user profile
  Future<AppUser> getMe() async {
    final res = await _api.get(ApiConstants.me);
    return AppUser.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Persist tokens locally
  Future<void> saveTokens(AuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token',  tokens.accessToken);
    await prefs.setString('id_token',      tokens.idToken);
    await prefs.setString('refresh_token', tokens.refreshToken);
    await prefs.setInt('login_timestamp',  DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('id_token');
    await prefs.remove('refresh_token');
    await prefs.remove('login_timestamp');
  }

  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<int?> getLoginTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('login_timestamp');
  }
}
