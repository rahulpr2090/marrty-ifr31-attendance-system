// lib/shared/widgets/main_shell.dart
// Bottom nav shell with 5 tabs, center FAB, live geofence indicator
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../features/auth/presentation/auth_provider.dart';

// ── Geofence state ─────────────────────────────────────
enum GeofenceStatus { unknown, checking, inZone, outOfZone, error }

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  GeofenceStatus _geoStatus = GeofenceStatus.unknown;
  Timer? _geoTimer;

  List<_TabItem> _tabs(bool isHod) => [
    const _TabItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', route: '/'),
    const _TabItem(icon: Icons.group_outlined, activeIcon: Icons.group, label: 'Students', route: '/students'),
    const _TabItem(icon: Icons.camera_alt_outlined, activeIcon: Icons.camera_alt, label: 'Scan', route: '/scan', isScan: true),
    const _TabItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment, label: 'Attendance', route: '/attendance'),
    const _TabItem(icon: Icons.more_horiz, activeIcon: Icons.more_horiz, label: 'More', route: '/more'),
  ];

  @override
  void initState() {
    super.initState();
    _checkGeofence();
    // Re-check geofence every 2 minutes
    _geoTimer = Timer.periodic(const Duration(minutes: 2), (_) => _checkGeofence());
  }

  @override
  void dispose() {
    _geoTimer?.cancel();
    super.dispose();
  }

  /// Check GPS against server-side geofence
  Future<void> _checkGeofence() async {
    if (!mounted) return;
    setState(() => _geoStatus = GeofenceStatus.checking);

    try {
      // Check & request location permissions
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) setState(() => _geoStatus = GeofenceStatus.error);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final res = await ApiClient.instance.post(ApiConstants.geofenceCheck, data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });

      if (!mounted) return;
      final inside = res['inside'] as bool? ?? false;
      setState(() => _geoStatus = inside ? GeofenceStatus.inZone : GeofenceStatus.outOfZone);
    } catch (_) {
      if (mounted) setState(() => _geoStatus = GeofenceStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isHod = user?.isHod ?? false;
    final tabs = _tabs(isHod);

    // Sync tab highlight with current route
    final loc = GoRouterState.of(context).uri.path;
    final routeIndex = tabs.indexWhere((t) => t.route == loc);
    if (routeIndex >= 0 && routeIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = routeIndex);
      });
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: widget.child,
      bottomNavigationBar: _buildBottomNav(tabs),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/marrty_logo.png',
              width: 32, height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Text('Marrty IFR31'),
        ],
      ),
      actions: [
        // Live geofence indicator
        GestureDetector(
          onTap: _checkGeofence,
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _geoColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_geoStatus == GeofenceStatus.checking)
                  const SizedBox(
                    width: 10, height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textSecLight),
                  )
                else
                  CircleAvatar(radius: 4, backgroundColor: _geoColor),
                const SizedBox(width: 4),
                Text(_geoLabel,
                  style: TextStyle(fontSize: 11, color: _geoColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        // Profile avatar
        Consumer(builder: (_, ref, __) {
          final user = ref.watch(currentUserProvider);
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.go('/more'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Geofence badge color based on live status
  Color get _geoColor {
    switch (_geoStatus) {
      case GeofenceStatus.inZone: return AppColors.success;
      case GeofenceStatus.outOfZone: return AppColors.error;
      case GeofenceStatus.checking: return AppColors.textSecLight;
      case GeofenceStatus.error: return AppColors.warning;
      case GeofenceStatus.unknown: return AppColors.textSecLight;
    }
  }

  /// Geofence badge label based on live status
  String get _geoLabel {
    switch (_geoStatus) {
      case GeofenceStatus.inZone: return 'In Zone';
      case GeofenceStatus.outOfZone: return 'Outside';
      case GeofenceStatus.checking: return 'Checking...';
      case GeofenceStatus.error: return 'GPS Off';
      case GeofenceStatus.unknown: return '—';
    }
  }

  Widget _buildBottomNav(List<_TabItem> tabs) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) {
        setState(() => _selectedIndex = i);
        context.go(tabs[i].route);
      },
      items: tabs.asMap().entries.map((e) {
        final tab = e.value;
        final isActive = _selectedIndex == e.key;

        if (tab.isScan) {
          return BottomNavigationBarItem(
            icon: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 26),
            ),
            label: tab.label,
          );
        }

        return BottomNavigationBarItem(
          icon: Icon(isActive ? tab.activeIcon : tab.icon),
          label: tab.label,
        );
      }).toList(),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final bool isScan;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.isScan = false,
  });
}
