// lib/features/auth/presentation/screens/change_password_screen.dart
// Force new password with visual strength indicator
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../auth_provider.dart';
import '../../../auth/domain/auth_models.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showNew      = false;
  bool _showConfirm  = false;
  bool _isLoading    = false;

  double _strength(String p) {
    double s = 0;
    if (p.length >= 10) s += 0.2;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.2;
    if (p.contains(RegExp(r'[a-z]'))) s += 0.2;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.2;
    if (p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) s += 0.2;
    return s;
  }

  Color _strengthColor(double s) {
    if (s < 0.4) return AppColors.error;
    if (s < 0.8) return AppColors.warning;
    return AppColors.success;
  }

  String _strengthLabel(double s) {
    if (s < 0.4) return 'Weak';
    if (s < 0.8) return 'Fair';
    return 'Strong';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    await ref.read(authProvider.notifier).changePassword(
      _newPassCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    final s = ref.read(authProvider).status;
    switch (s) {
      case AuthStatus.requiresMfaSetup:
        context.go('/mfa-setup');
        break;
      case AuthStatus.requiresMfaVerify:
        context.go('/mfa-verify');
        break;
      case AuthStatus.authenticated:
        context.go('/');
        break;
      case AuthStatus.unauthenticated:
        // Password changed successfully → back to login
        context.go('/login');
        break;
      default:
        // Stay on this page (error shown via state)
        break;
    }
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final pass = _newPassCtrl.text;
    final str  = _strength(pass);

    return Scaffold(
      appBar: AppBar(title: const Text('Set New Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create a strong password',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Must have 10+ characters, uppercase, lowercase, number, symbol',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _newPassCtrl,
                  obscureText: !_showNew,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showNew = !_showNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (_strength(v) < 0.8) return 'Password too weak';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Strength bar
                if (pass.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: str,
                      color: _strengthColor(str),
                      backgroundColor: AppColors.dividerLight,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_strengthLabel(str),
                      style: TextStyle(color: _strengthColor(str), fontSize: 12)),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: !_showConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v != _newPassCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Error message from auth state
                if (authState.errorMessage != null &&
                    authState.status == AuthStatus.requiresPasswordChange)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 22, width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
