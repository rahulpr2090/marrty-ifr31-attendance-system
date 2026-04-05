// lib/features/auth/presentation/auth_provider.dart
// Riverpod StateNotifier for auth state + 12-hour session timer
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';
import '../../../core/constants/app_constants.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthRepository());
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).user;
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  Timer? _sessionTimer;
  Timer? _warningTimer;

  AuthNotifier(this._repo) : super(const AuthState.initial()) {
    _checkExistingSession();
  }

  // ── Check existing session on app start ──────────────
  Future<void> _checkExistingSession() async {
    final token = await _repo.getSavedToken();
    if (token == null) return;

    final loginTs = await _repo.getLoginTimestamp();
    if (loginTs == null) return;

    final elapsed = DateTime.now().millisecondsSinceEpoch - loginTs;
    final sessionMax = AppConstants.sessionDurationHours * 3600 * 1000;

    if (elapsed >= sessionMax) {
      state = state.copyWith(status: AuthStatus.sessionExpired);
      await _repo.clearTokens();
      return;
    }

    try {
      final user = await _repo.getMe();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      _startSessionTimer(remainingMs: sessionMax - elapsed);
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  // ── Login ─────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, email: email);
    try {
      final res = await _repo.login(email, password);
      await _handleResponse(res, email: email);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceFirst('ApiException', '').trim(),
      );
    }
  }

  // ── MFA verify ───────────────────────────────────────
  Future<void> verifyMfa(String code) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final res = await _repo.verifyMfa(
        session: state.session!,
        code: code,
        challengeName: state.challengeName!,
      );
      await _handleResponse(res);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.requiresMfaVerify,
        errorMessage: 'Invalid code. Please try again.',
      );
    }
  }

  // ── Force password change ────────────────────────────
  Future<void> changePassword(String newPassword) async {
    final email = state.email ?? '';
    if (email.isEmpty || state.session == null) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Session expired. Please login again.',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.loading);
    try {
      final res = await _repo.changePassword(
        email: email,
        session: state.session!,
        newPassword: newPassword,
      );
      await _handleResponse(res, email: email);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.requiresPasswordChange,
        errorMessage: e.toString().replaceFirst('ApiException', '').trim(),
      );
    }
  }

  // ── Parse API challenge/token response ───────────────
  Future<void> _handleResponse(Map<String, dynamic> res, {String? email}) async {
    // Backend returns field 'challenge' for Cognito challenges
    final challenge = res['challenge'] as String?;

    if (challenge == 'NEW_PASSWORD_REQUIRED') {
      state = state.copyWith(
        status: AuthStatus.requiresPasswordChange,
        session: res['session'] as String?,
        email: email,
        errorMessage: null,
      );
      return;
    }

    if (challenge == 'MFA_SETUP') {
      state = state.copyWith(
        status: AuthStatus.requiresMfaSetup,
        session: res['session'] as String?,
        challengeName: 'MFA_SETUP',
        secretCode: res['secretCode'] as String?,
        email: email,
        errorMessage: null,
      );
      return;
    }

    if (challenge == 'SOFTWARE_TOKEN_MFA') {
      state = state.copyWith(
        status: AuthStatus.requiresMfaVerify,
        session: res['session'] as String?,
        challengeName: 'SOFTWARE_TOKEN_MFA',
        email: email,
        errorMessage: null,
      );
      return;
    }

    // ── Authenticated (tokens returned) ───────────────
    if (res['accessToken'] != null) {
      final tokens = AuthTokens.fromJson(res);
      await _repo.saveTokens(tokens);
      final user = await _repo.getMe();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
      _startSessionTimer();
      return;
    }

    // ── Password changed successfully (no tokens) ─────
    // Backend returns {"message": "Password changed successfully"}
    // or {"message": "MFA setup complete. Please login again."}
    // User must re-login with the new password.
    if (res['message'] != null && challenge == null) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: '${res['message']} Please sign in again.',
      );
      return;
    }
  }

  // ── Session timer (12 hours) ─────────────────────────
  void _startSessionTimer({int? remainingMs}) {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();

    final totalMs = AppConstants.sessionDurationHours * 3600 * 1000;
    final remaining = remainingMs ?? totalMs;
    final warnAt = remaining - AppConstants.sessionWarningMinutes * 60 * 1000;

    if (warnAt > 0) {
      _warningTimer = Timer(Duration(milliseconds: warnAt), () {
        state = state.copyWith(errorMessage: 'session_expiring_soon');
      });
    }

    _sessionTimer = Timer(Duration(milliseconds: remaining), () async {
      await logout();
      state = state.copyWith(status: AuthStatus.sessionExpired);
    });
  }

  // ── Logout ───────────────────────────────────────────
  Future<void> logout() async {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    await _repo.clearTokens();
    state = const AuthState.initial();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    super.dispose();
  }
}
