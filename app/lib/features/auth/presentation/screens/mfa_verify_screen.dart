// lib/features/auth/presentation/screens/mfa_verify_screen.dart
// MFA setup (show TOTP secret) + verify (enter 6-digit code)
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../auth_provider.dart';
import '../../../auth/domain/auth_models.dart';

class MfaVerifyScreen extends ConsumerStatefulWidget {
  const MfaVerifyScreen({super.key});
  @override
  ConsumerState<MfaVerifyScreen> createState() => _MfaVerifyScreenState();
}

class _MfaVerifyScreenState extends ConsumerState<MfaVerifyScreen> {
  final List<TextEditingController> _ctrlList =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusList = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _secretCopied = false;

  String get _code => _ctrlList.map((c) => c.text).join();

  bool get _isSetupMode {
    final s = ref.read(authProvider);
    return s.status == AuthStatus.requiresMfaSetup ||
           s.challengeName == 'MFA_SETUP';
  }

  @override
  void dispose() {
    for (final c in _ctrlList) c.dispose();
    for (final f in _focusList) f.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.length < 6) return;
    setState(() => _isLoading = true);

    await ref.read(authProvider.notifier).verifyMfa(_code);

    if (!mounted) return;
    setState(() => _isLoading = false);

    final s = ref.read(authProvider).status;
    if (s == AuthStatus.authenticated) {
      context.go('/');
    } else if (s == AuthStatus.unauthenticated) {
      // MFA setup complete → re-login
      context.go('/login');
    }
  }

  void _copySecret(String secret) {
    Clipboard.setData(ClipboardData(text: secret));
    setState(() => _secretCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Secret copied! Paste it in your Authenticator app.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final err = authState.errorMessage;
    final isSetup = _isSetupMode;
    final secret = authState.secretCode;

    return Scaffold(
      appBar: AppBar(title: Text(isSetup ? 'Setup Authenticator' : 'Two-Factor Auth')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Icon(
                isSetup ? Icons.qr_code_2 : Icons.security,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),

              Text(
                isSetup ? 'Setup Two-Factor Auth' : 'Enter Verification Code',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),

              // ── Setup mode: show secret code ──────────────
              if (isSetup) ...[
                Text(
                  'Add this account to your Authenticator app\n(Google Authenticator or Microsoft Authenticator)',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                if (secret != null && secret.isNotEmpty) ...[
                  // Steps
                  _buildStep('1', 'Open your Authenticator app'),
                  _buildStep('2', 'Tap + → "Enter setup key"'),
                  _buildStep('3', 'Copy the secret below & paste it'),
                  const SizedBox(height: 16),

                  // Secret code card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('Your Secret Key',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                        const SizedBox(height: 8),
                        SelectableText(
                          secret,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _copySecret(secret),
                          icon: Icon(_secretCopied ? Icons.check : Icons.copy, size: 18),
                          label: Text(_secretCopied ? 'Copied!' : 'Copy Secret'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Account: ${authState.email ?? "Marrty IFR31"}',
                      style: Theme.of(context).textTheme.bodySmall),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No TOTP secret received. Please go back and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('Then enter the 6-digit code from the app:',
                    style: Theme.of(context).textTheme.bodyMedium),
              ] else ...[
                // ── Verify mode ──────────────────────────────
                Text('Enter the 6-digit code from your Authenticator app',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center),
              ],

              const SizedBox(height: 24),

              // ── 6-digit boxes ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => _digitBox(i)),
              ),

              if (err != null && err != 'session_expiring_soon') ...[
                const SizedBox(height: 12),
                Text(err,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                    textAlign: TextAlign.center),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_code.length == 6 && !_isLoading) ? _submit : null,
                  child: _isLoading
                      ? const SizedBox(height: 22, width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isSetup ? 'Complete Setup' : 'Verify'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _digitBox(int i) {
    return Container(
      width: 44, height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: _focusList[i].hasFocus ? AppColors.primary : AppColors.dividerLight,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        controller: _ctrlList[i],
        focusNode: _focusList[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) {
            _focusList[i + 1].requestFocus();
          } else if (v.isEmpty && i > 0) {
            _focusList[i - 1].requestFocus();
          }
          setState(() {});
          if (_code.length == 6) _submit();
        },
      ),
    );
  }
}
