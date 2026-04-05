// lib/core/network/api_client.dart
// Dio client with Cognito JWT auth interceptor + auto-logout on 401
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiException implements Exception {
  final String message;
  final int?   statusCode;
  ApiException(this.message, {this.statusCode});
  @override String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient._();
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  late final Dio _dio;
  Function()? onUnauthorized; // Set by auth provider to trigger logout

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    // ── Auth interceptor ─────────────────────────────
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        // Cognito authorizer on API Gateway validates the idToken, not accessToken
        final token = prefs.getString('id_token');
        if (token != null) {
          options.headers['Authorization'] = token;
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  // ── Generic request wrapper ──────────────────────────
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    try {
      final r = await _dio.get(path, queryParameters: params);
      return r.data;
    } on DioException catch (e) {
      throw _convert(e);
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final r = await _dio.post(path, data: data);
      return r.data;
    } on DioException catch (e) {
      throw _convert(e);
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final r = await _dio.put(path, data: data);
      return r.data;
    } on DioException catch (e) {
      throw _convert(e);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final r = await _dio.delete(path);
      return r.data;
    } on DioException catch (e) {
      throw _convert(e);
    }
  }

  ApiException _convert(DioException e) {
    final statusCode = e.response?.statusCode;
    final msg = e.response?.data?['message'] as String? ??
                e.message ?? 'Unknown error';
    return ApiException(msg, statusCode: statusCode);
  }
}
