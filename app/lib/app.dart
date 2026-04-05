// lib/app.dart — Router + theme setup
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/auth_models.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/change_password_screen.dart';
import 'features/auth/presentation/screens/mfa_verify_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/students/presentation/students_screen.dart';
import 'features/face_scan/presentation/face_scan_screen.dart';
import 'features/attendance/presentation/attendance_screen.dart';
import 'features/reports/presentation/reports_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'shared/widgets/main_shell.dart';

// ── Theme provider ────────────────────────────────────
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved == 'light') state = ThemeMode.light;
    if (saved == 'dark')  state = ThemeMode.dark;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode',
        mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system');
  }
}

// ── Router ────────────────────────────────────────────
final _routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final s = authState.status;
      final loc = state.uri.path;

      // Don't redirect while loading — prevents blackout screen
      if (s == AuthStatus.loading) return null;

      if (s == AuthStatus.authenticated && loc == '/login') return '/';
      if (s == AuthStatus.unauthenticated && loc != '/login') return '/login';
      if (s == AuthStatus.sessionExpired) return '/login';
      if (s == AuthStatus.requiresPasswordChange && loc != '/change-password') {
        return '/change-password';
      }
      if (s == AuthStatus.requiresMfaSetup && loc != '/mfa-setup') {
        return '/mfa-setup';
      }
      if (s == AuthStatus.requiresMfaVerify && loc != '/mfa-verify') {
        return '/mfa-verify';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/change-password', builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/mfa-setup',       builder: (_, __) => const MfaVerifyScreen()),
      GoRoute(path: '/mfa-verify',      builder: (_, __) => const MfaVerifyScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/',            builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/students',    builder: (_, __) => const StudentsScreen()),
          GoRoute(path: '/scan',        builder: (_, __) => const FaceScanScreen()),
          GoRoute(path: '/attendance',  builder: (_, __) => const AttendanceScreen()),
          GoRoute(path: '/more',        builder: (_, __) => const SettingsScreen()),
        ],
      ),
      // Reports accessed from Settings "More" menu
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
    ],
  );
});

// ── Main app widget ───────────────────────────────────
class MarrtyApp extends ConsumerWidget {
  const MarrtyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router    = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'Marrty IFR31',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
