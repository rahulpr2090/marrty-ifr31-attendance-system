// lib/features/settings/presentation/settings_screen.dart
// Settings: profile, security, appearance, HOD system config, bug reports
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../features/auth/presentation/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final user  = ref.watch(currentUserProvider);
    final isHod = user?.isHod ?? false;
    final tm    = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & More')),
      body: ListView(children: [

        // ── Profile ─────────────────────────────────────
        _SectionTitle('Profile'),
        Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            CircleAvatar(
              radius: 28, backgroundColor: AppColors.primary,
              child: Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.name ?? 'User', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecLight, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(user?.role.toUpperCase() ?? '',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ])),
          ])),
        ),

        // ── Security ────────────────────────────────────
        _SectionTitle('Security'),
        _SettingTile(
          icon: Icons.security,
          title: '2FA Authentication',
          subtitle: 'Optional · Not configured',
          onTap: () => _showMfaInfo(context),
        ),
        _SettingTile(
          icon: Icons.timer,
          title: 'Session Info',
          subtitle: 'Auto-logout after ${AppConstants.sessionDurationHours}h',
          onTap: () => _showSessionInfo(context),
        ),
        _SettingTile(
          icon: Icons.lock_reset,
          title: 'Change Password',
          subtitle: 'Update your password',
          onTap: () => _showChangePassword(context),
        ),

        // ── Appearance ──────────────────────────────────
        _SectionTitle('Appearance'),
        Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.palette_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _ThemeChip(icon: Icons.light_mode, label: 'Light', mode: ThemeMode.light, current: tm),
                const SizedBox(width: 8),
                _ThemeChip(icon: Icons.dark_mode, label: 'Dark', mode: ThemeMode.dark, current: tm),
                const SizedBox(width: 8),
                _ThemeChip(icon: Icons.brightness_auto, label: 'System', mode: ThemeMode.system, current: tm),
              ]),
            ],
          )),
        ),

        // ── HOD-only system settings ─────────────────────
        if (isHod) ...[
          _SectionTitle('System (HOD)'),
          _SettingTile(icon: Icons.schedule, title: 'Session Timings',
            subtitle: 'Configure session times',
            onTap: () => _showSessionConfig(context)),
          _SettingTile(icon: Icons.location_on, title: 'Geofence Setup',
            subtitle: 'Set attendance zone',
            onTap: () => _showGeofenceSetup(context)),
          _SettingTile(icon: Icons.admin_panel_settings, title: 'Manage Sub-Admins',
            subtitle: 'Add or remove sub-admins',
            onTap: () => _showSubAdminManagement(context)),
          _SettingTile(icon: Icons.history, title: 'Audit Log',
            onTap: () => _showAuditLog(context)),
        ],

        // ── Bug reports ──────────────────────────────────
        _SectionTitle('Support'),
        _SettingTile(icon: Icons.bug_report, title: 'Submit Bug Report',
          onTap: () => _submitBug(context)),
        _SettingTile(icon: Icons.list_alt, title: 'My Bug Reports',
          onTap: () => _showMyBugs(context)),

        // ── About ────────────────────────────────────────
        _SectionTitle('About'),
        Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marrty IFR31', style: Theme.of(context).textTheme.titleMedium),
              const Text('Dept. of Computer Engineering · HGPC',
                style: TextStyle(color: AppColors.textSecLight, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Version ${AppConstants.appVersion}',
                style: const TextStyle(color: AppColors.textSecLight, fontSize: 12)),
              const SizedBox(height: 4),
              const Text('© 2026 Marrty LLC. All rights reserved.',
                style: TextStyle(color: AppColors.textSecLight, fontSize: 10)),
            ],
          )),
        ),

        // ── Logout ──────────────────────────────────────
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Logout', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── MFA Info ──────────────────────────────────────────
  void _showMfaInfo(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Two-Factor Authentication'),
      content: const Text(
        'MFA is currently optional and not configured.\n\n'
        'To enable 2FA:\n'
        '1. Contact HOD to enable mandatory MFA\n'
        '2. On next login you will be prompted to set up an authenticator app\n'
        '3. Scan a QR code or enter the secret key manually',
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ));
  }

  // ── Session Info ──────────────────────────────────────
  void _showSessionInfo(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Session Info'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('• Session duration: ${AppConstants.sessionDurationHours} hours', style: const TextStyle(fontSize: 13)),
        Text('• Warning at ${AppConstants.sessionDurationHours}h ${60 - AppConstants.sessionWarningMinutes}m', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        const Text('Auto-logout when session expires for security.',
          style: TextStyle(color: AppColors.textSecLight, fontSize: 12)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ));
  }

  // ── Change Password (in-app) ──────────────────────────
  void _showChangePassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool loading = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: currentCtrl, obscureText: true,
            decoration: const InputDecoration(labelText: 'Current Password')),
          const SizedBox(height: 12),
          TextField(controller: newCtrl, obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              helperText: 'Min 8 chars, uppercase, lowercase, number, symbol',
              helperMaxLines: 2,
            )),
          const SizedBox(height: 12),
          TextField(controller: confirmCtrl, obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm New Password')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: loading ? null : () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.error));
                return;
              }
              if (newCtrl.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 8 characters'), backgroundColor: AppColors.error));
                return;
              }
              setS(() => loading = true);
              try {
                // Re-login with current password to get session, then change
                final loginRes = await ApiClient.instance.post(ApiConstants.login, data: {
                  'email': ref.read(currentUserProvider)?.email ?? '',
                  'password': currentCtrl.text,
                });
                final loginData = Map<String, dynamic>.from(loginRes as Map);

                // If login returns tokens directly, use Cognito admin endpoint
                if (loginData['accessToken'] != null) {
                  // User is authenticated — call change-password with session
                  await ApiClient.instance.post(ApiConstants.changePassword, data: {
                    'email': ref.read(currentUserProvider)?.email ?? '',
                    'newPassword': newCtrl.text,
                    'currentPassword': currentCtrl.text,
                  });
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Password changed successfully'), backgroundColor: AppColors.success));
                }
              } catch (e) {
                setS(() => loading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Change Password'),
          ),
        ],
      ),
    ));
  }

  // ── Session Config (HOD) ──────────────────────────────
  void _showSessionConfig(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _SessionConfigScreen()));
  }

  // ── Geofence Setup (HOD) ──────────────────────────────
  void _showGeofenceSetup(BuildContext context) {
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '200');
    bool loading = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Geofence Setup'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Set the attendance zone center and radius.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecLight)),
          const SizedBox(height: 12),
          TextField(controller: latCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Latitude', hintText: 'e.g. 10.0452')),
          const SizedBox(height: 8),
          TextField(controller: lngCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Longitude', hintText: 'e.g. 76.3294')),
          const SizedBox(height: 8),
          TextField(controller: radiusCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Radius (meters)', hintText: '50-500')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: loading ? null : () async {
              final lat = double.tryParse(latCtrl.text);
              final lng = double.tryParse(lngCtrl.text);
              final radius = double.tryParse(radiusCtrl.text);
              if (lat == null || lng == null || radius == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid numbers'), backgroundColor: AppColors.error));
                return;
              }
              setS(() => loading = true);
              try {
                await ApiClient.instance.put(ApiConstants.geofence, data: {
                  'center': {'lat': lat, 'lng': lng},
                  'radiusMeters': radius.toInt(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Geofence updated'), backgroundColor: AppColors.success));
                }
              } catch (e) {
                setS(() => loading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Geofence'),
          ),
        ],
      ),
    ));
  }

  // ── Sub-Admin Management (HOD) ────────────────────────
  void _showSubAdminManagement(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _SubAdminScreen()));
  }

  void _logout(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            ref.read(authProvider.notifier).logout();
          },
          child: const Text('Logout', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ));
  }

  void _showAuditLog(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _AuditLogScreen()));
  }

  void _submitBug(BuildContext context) {
    final descCtrl = TextEditingController();
    String type = 'bug';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Submit Bug Report'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: ['bug', 'technical', 'feature', 'other'].map((t) =>
                DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
            onChanged: (v) => setS(() => type = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Describe the issue in detail (min 10 chars)...',
            )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (descCtrl.text.trim().length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Description must be at least 10 characters'), backgroundColor: AppColors.error));
                return;
              }
              try {
                await ApiClient.instance.post(ApiConstants.bugs, data: {
                  'type': type, 'description': descCtrl.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Report submitted'), backgroundColor: AppColors.success));
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    ));
  }

  void _showMyBugs(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _BugListScreen()));
  }
}

// ════════════════════════════════════════════════════════════
// SESSION CONFIG SCREEN (HOD)
// ════════════════════════════════════════════════════════════

class _SessionConfigScreen extends StatefulWidget {
  const _SessionConfigScreen();
  @override State<_SessionConfigScreen> createState() => _SessionConfigScreenState();
}

class _SessionConfigScreenState extends State<_SessionConfigScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(ApiConstants.sessions);
      final list = res['sessions'] as List? ?? [];
      setState(() {
        _sessions = List<Map<String, dynamic>>.from(list);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  /// Initialize default sessions if none exist
  Future<void> _initSessions() async {
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('${ApiConstants.sessions}/init');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Sessions initialized'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  /// Edit session timing
  void _editSession(Map<String, dynamic> session) {
    final startCtrl = TextEditingController(text: session['startTime'] as String? ?? '');
    final endCtrl = TextEditingController(text: session['endTime'] as String? ?? '');
    bool saving = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text('Edit ${session['name']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: startCtrl,
            decoration: const InputDecoration(labelText: 'Start Time', hintText: 'HH:mm (e.g. 08:30)')),
          const SizedBox(height: 12),
          TextField(controller: endCtrl,
            decoration: const InputDecoration(labelText: 'End Time', hintText: 'HH:mm (e.g. 10:00)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: saving ? null : () async {
              if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(startCtrl.text) ||
                  !RegExp(r'^\d{2}:\d{2}$').hasMatch(endCtrl.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Use HH:mm format'), backgroundColor: AppColors.error));
                return;
              }
              setS(() => saving = true);
              try {
                await ApiClient.instance.put(
                  '${ApiConstants.sessions}/${session['sessionId']}',
                  data: {'startTime': startCtrl.text, 'endTime': endCtrl.text},
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${session['name']} updated'), backgroundColor: AppColors.success));
                }
              } catch (e) {
                setS(() => saving = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Session Configuration')),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _sessions.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.schedule, size: 64, color: AppColors.textSecLight),
                const SizedBox(height: 12),
                const Text('No sessions configured'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _initSessions,
                  icon: const Icon(Icons.add),
                  label: const Text('Initialize Default Sessions'),
                ),
              ]))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (_, i) {
                    final s = _sessions[i];
                    final isActive = s['isActive'] as bool? ?? false;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.textSecLight.withValues(alpha: 0.12),
                          child: Icon(Icons.schedule,
                            color: isActive ? AppColors.primary : AppColors.textSecLight),
                        ),
                        title: Text(s['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${s['startTime']} — ${s['endTime']}',
                          style: const TextStyle(fontSize: 13)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isActive ? AppColors.success : AppColors.textSecLight).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(isActive ? 'Active' : 'Off',
                              style: TextStyle(fontSize: 11,
                                color: isActive ? AppColors.success : AppColors.textSecLight,
                                fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _editSession(s),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
  );
}

// ════════════════════════════════════════════════════════════
// SUB-ADMIN MANAGEMENT SCREEN
// ════════════════════════════════════════════════════════════

class _SubAdminScreen extends StatefulWidget {
  const _SubAdminScreen();
  @override State<_SubAdminScreen> createState() => _SubAdminScreenState();
}

class _SubAdminScreenState extends State<_SubAdminScreen> {
  List<Map<String, dynamic>> _admins = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(ApiConstants.subAdmins);
      setState(() {
        _admins = List<Map<String, dynamic>>.from(res['subAdmins'] as List? ?? []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  void _addSubAdmin() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool saving = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Add Sub-Admin'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          const Text('A temporary password will be sent to this email.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecLight)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: saving ? null : () async {
              if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) return;
              setS(() => saving = true);
              try {
                await ApiClient.instance.post(ApiConstants.subAdmins, data: {
                  'name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim().toLowerCase(),
                  'permissions': {
                    'batches': AppConstants.batchYears,
                    'semesters': AppConstants.semesters,
                    'canMarkAttendance': true,
                    'canManageStudents': true,
                  },
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Sub-admin created'), backgroundColor: AppColors.success));
                }
              } catch (e) {
                setS(() => saving = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create'),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sub-Admins')),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _admins.isEmpty
            ? const Center(child: Text('No sub-admins created'))
            : ListView.builder(
                itemCount: _admins.length,
                itemBuilder: (_, i) {
                  final a = _admins[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text((a['name'] as String? ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(a['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(a['email'] as String? ?? '', style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
    floatingActionButton: FloatingActionButton(
      backgroundColor: AppColors.primary,
      onPressed: _addSubAdmin,
      child: const Icon(Icons.person_add, color: Colors.white),
    ),
  );
}

// ════════════════════════════════════════════════════════════
// WIDGET HELPERS
// ════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(title, style: const TextStyle(
      color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8)),
  );
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _SettingTile({required this.icon, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecLight),
      onTap: onTap,
    ),
  );
}

class _ThemeChip extends ConsumerWidget {
  final IconData icon;
  final String label;
  final ThemeMode mode;
  final ThemeMode current;
  const _ThemeChip({required this.icon, required this.label, required this.mode, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = current == mode;
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).setTheme(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.dividerLight),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textSecLight),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textLight)),
        ]),
      ),
    );
  }
}

// ── Simple Audit Log Screen ───────────────────────────
class _AuditLogScreen extends StatefulWidget {
  const _AuditLogScreen();
  @override State<_AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<_AuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.auditLogs);
      setState(() {
        _logs = List<Map<String, dynamic>>.from(res['logs'] as List? ?? []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Audit Log')),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _logs.isEmpty
            ? const Center(child: Text('No audit logs'))
            : ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) {
                  final l = _logs[i];
                  return ListTile(
                    leading: const Icon(Icons.history, color: AppColors.primary),
                    title: Text('${l['action']} on ${l['target']}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('${l['actor']} · ${l['timestamp']}',
                      style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
  );
}

// ── Bug list screen ──────────────────────────────────
class _BugListScreen extends StatefulWidget {
  const _BugListScreen();
  @override State<_BugListScreen> createState() => _BugListScreenState();
}

class _BugListScreenState extends State<_BugListScreen> {
  List<Map<String, dynamic>> _bugs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.bugs);
      setState(() {
        _bugs = List<Map<String, dynamic>>.from(res['bugs'] as List? ?? []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Color _statusColor(String s) {
    if (s == 'Resolved') return AppColors.present;
    if (s == 'In Review') return AppColors.warning;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Bug Reports')),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _bugs.isEmpty
            ? const Center(child: Text('No reports submitted'))
            : ListView.builder(
                itemCount: _bugs.length,
                itemBuilder: (_, i) {
                  final b = _bugs[i];
                  final status = b['status'] as String? ?? 'Open';
                  return ListTile(
                    leading: const Icon(Icons.bug_report_outlined, color: AppColors.primary),
                    title: Text(b['description'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('${b['type']} · ${b['createdAt']}',
                      style: const TextStyle(fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(status,
                        style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              ),
  );
}
