import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_theme.dart';

/// Two-step forgot-password screen.
///
/// Step 1 — user enters their email → OTP is sent.
/// Step 2 — user enters OTP + new password → password is updated.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _confirmKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _step2 = false; // false = enter email, true = enter code + new pw
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (!_emailKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final res = await ref
        .read(authRepositoryProvider)
        .requestPasswordReset(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    res.when(
      success: (_) {
        setState(() => _step2 = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset code sent — check your email'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      failure: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppTheme.lossRed),
      ),
    );
  }

  Future<void> _confirmReset() async {
    if (!_confirmKey.currentState!.validate()) return;
    if (_newPwCtrl.text != _confirmPwCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppTheme.lossRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await ref.read(authRepositoryProvider).confirmPasswordReset(
          email: _emailCtrl.text.trim(),
          code: _codeCtrl.text.trim(),
          newPassword: _newPwCtrl.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    res.when(
      success: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.profitGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/login');
      },
      failure: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppTheme.lossRed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _step2
                    ? _buildConfirmStep(theme)
                    : _buildRequestStep(theme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestStep(ThemeData theme) {
    return Form(
      key: _emailKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              label: const Text('Back to Login'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
            ),
            child: const Icon(Icons.lock_reset_rounded,
                size: 36, color: Colors.white),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

          const SizedBox(height: AppTheme.spacingLg),

          Text(
            'Reset Password',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 8),
          Text(
            'Enter your registered email. We\'ll send a 6-digit code.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: AppTheme.spacingXl),

          // Email field
          TextFormField(
            key: const Key('reset_email_field'),
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06),

          const SizedBox(height: AppTheme.spacingLg),

          // Send Code button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              key: const Key('send_reset_code_button'),
              onPressed: _isLoading ? null : _requestReset,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Reset Code',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ).animate().fadeIn(delay: 250.ms),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(ThemeData theme) {
    return Form(
      key: _confirmKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back to step 1
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _step2 = false),
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              label: const Text('Change email'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),

          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.profitGreen, theme.colorScheme.primary],
              ),
            ),
            child: const Icon(Icons.verified_user_rounded,
                size: 36, color: Colors.white),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

          const SizedBox(height: AppTheme.spacingLg),

          Text(
            'Enter Reset Code',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 50.ms),

          const SizedBox(height: 8),
          Text(
            'Code sent to ${_emailCtrl.text.trim()}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: AppTheme.spacingXl),

          // OTP code field
          TextFormField(
            key: const Key('reset_code_field'),
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '6-digit code',
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().length != 6) {
                return 'Enter the 6-digit code from your email';
              }
              return null;
            },
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.06),

          const SizedBox(height: AppTheme.spacingMd),

          // New password field
          TextFormField(
            key: const Key('reset_new_password_field'),
            controller: _newPwCtrl,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06),

          const SizedBox(height: AppTheme.spacingMd),

          // Confirm password field
          TextFormField(
            key: const Key('reset_confirm_password_field'),
            controller: _confirmPwCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              return null;
            },
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.06),

          const SizedBox(height: AppTheme.spacingLg),

          // Confirm button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              key: const Key('confirm_reset_button'),
              onPressed: _isLoading ? null : _confirmReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.profitGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Set New Password',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: AppTheme.spacingMd),

          // Resend link
          Center(
            child: TextButton(
              key: const Key('resend_code_button'),
              onPressed: _isLoading ? null : _requestReset,
              child: const Text('Resend code'),
            ),
          ),
        ],
      ),
    );
  }
}
