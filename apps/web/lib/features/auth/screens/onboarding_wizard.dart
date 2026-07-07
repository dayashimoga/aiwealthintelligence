import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/repositories/repositories.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState
    extends ConsumerState<OnboardingWizardScreen> {
  final PageController _pageController = PageController();
  final LocalAuthentication _auth = LocalAuthentication();
  int _currentPage = 0;
  bool _isLoading = false;

  // Step 2 State
  bool _isBiometricsEnabled = false;
  bool _isPasskeyRegistered = false;
  bool _isTotpEnabled = false;
  String _totpSecret = '';
  String _totpQrUri = '';
  final _totpController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _setupBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Biometrics not supported on this device')),
          );
        }
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to enable biometric login',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuthenticate) {
        setState(() => _isBiometricsEnabled = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Biometric access enabled successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biometrics error: $e')),
        );
      }
    }
  }

  Future<void> _registerPasskey() async {
    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);
    final optRes = await authRepo.passkeyRegisterOptions();

    optRes.when(
      success: (data) async {
        // mock passkey client-side authentication callback verification
        final verifyRes = await authRepo.passkeyRegisterVerify(
          credentialId: 'passkey-mock-credential-id',
          clientDataJson: 'mock-client-data-json',
          authenticatorData: 'mock-authenticator-data',
          signature: 'mock-passkey-sig-assertion',
        );

        verifyRes.when(
          success: (msg) {
            setState(() {
              _isLoading = false;
              _isPasskeyRegistered = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          },
          failure: (err, _) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err)),
            );
          },
        );
      },
      failure: (err, _) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      },
    );
  }

  Future<void> _setupTotpMfa() async {
    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);
    final res = await authRepo.setupTotp();

    res.when(
      success: (data) {
        setState(() {
          _isLoading = false;
          _totpSecret = data['secret'] as String;
          _totpQrUri = data['provisioning_uri'] as String;
        });
      },
      failure: (err, _) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      },
    );
  }

  Future<void> _verifyAndEnableTotp() async {
    if (_totpController.text.length < 6) return;
    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);
    final res = await authRepo.enableTotp(code: _totpController.text);

    res.when(
      success: (backupCodes) {
        setState(() {
          _isLoading = false;
          _isTotpEnabled = true;
          _totpSecret = '';
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('TOTP Enabled Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Save your backup codes somewhere safe:'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    backupCodes.join('\n'),
                    style: const TextStyle(
                        fontFamily: 'monospace', color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I saved them'),
              ),
            ],
          ),
        );
      },
      failure: (err, _) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid code: $err')),
        );
      },
    );
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);
    final res = await authRepo.completeOnboarding();

    res.when(
      success: (msg) {
        setState(() => _isLoading = false);
        context.go('/dashboard');
      },
      failure: (err, _) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: theme.brightness == Brightness.dark
              ? AppTheme.darkBgGradient
              : null,
        ),
        child: Column(
          children: [
            // Progress Bar header
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                    vertical: AppTheme.spacingMd),
                child: Row(
                  children: List.generate(3, (index) {
                    final active = index <= _currentPage;
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Page contents
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildTourPage(theme),
                  _buildSecurityPage(theme),
                  _buildImportPage(theme),
                ],
              ),
            ),

            // Footer controls
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_currentPage < 2) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _finishOnboarding();
                            }
                          },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_currentPage == 2 ? 'Get Started' : 'Next'),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.auto_awesome, size: 80, color: theme.colorScheme.primary)
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .rotate(duration: 600.ms),
          const SizedBox(height: 24),
          Text(
            'Meet WealthAI',
            style: theme.textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your intelligent, institutional-grade portfolio copilot. Track assets, run stress scenarios, and receive AI-driven adjustments to grow your wealth safely.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(180)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _buildTourCard(
            theme,
            icon: Icons.sync_alt,
            title: 'Auto synchronization',
            description:
                'Direct integration with consolidated account statements (CAS) or broker reports.',
          ),
          const SizedBox(height: 16),
          _buildTourCard(
            theme,
            icon: Icons.analytics_outlined,
            title: 'Actionable Portfolio Doctor',
            description:
                'Uncover hidden asset overlaps, evaluate tax-loss harvesting, and optimize yields.',
          ),
        ],
      ),
    );
  }

  Widget _buildTourCard(ThemeData theme,
      {required IconData icon,
      required String title,
      required String description}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(160))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Secure your account',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'We protect your private financial records with state-of-the-art security features.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
          ),
          const SizedBox(height: 32),

          // Biometrics
          _buildActionCard(
            theme,
            icon: Icons.fingerprint,
            title: 'Biometric unlock',
            description:
                'Quickly unlock the application using Face ID or fingerprint scans.',
            statusText: _isBiometricsEnabled ? 'Enabled' : 'Not setup',
            onTap: _setupBiometrics,
            enabled: _isBiometricsEnabled,
          ),
          const SizedBox(height: 16),

          // Passkey
          _buildActionCard(
            theme,
            icon: Icons.vpn_key_outlined,
            title: 'Register passkey credential',
            description:
                'Sign in securely without passwords using hardware authenticators.',
            statusText: _isPasskeyRegistered ? 'Registered' : 'Setup now',
            onTap: _registerPasskey,
            enabled: _isPasskeyRegistered,
          ),
          const SizedBox(height: 16),

          // Two-Factor Authentication
          _buildActionCard(
            theme,
            icon: Icons.security,
            title: 'TOTP Two-Factor Authenticator',
            description:
                'Require a verification code from Google Authenticator / 1Password.',
            statusText: _isTotpEnabled
                ? 'Enabled'
                : (_totpSecret.isNotEmpty ? 'Enter code' : 'Setup TOTP'),
            onTap: _isTotpEnabled
                ? null
                : () {
                    if (_totpSecret.isEmpty) {
                      _setupTotpMfa();
                    }
                  },
            enabled: _isTotpEnabled,
          ),

          if (_totpSecret.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Enter code from your Authenticator app to enable:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Secret key: $_totpSecret',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _totpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '6-digit verification code',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _verifyAndEnableTotp,
                        child: const Text('Verify'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
    required String statusText,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: enabled
              ? theme.colorScheme.primary.withAlpha(128)
              : theme.colorScheme.outlineVariant,
          width: enabled ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon,
            size: 36,
            color: enabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(description),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.green.withAlpha(30)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: enabled
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildImportPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Link your wealth portfolio',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Import your holdings to enable the AI doctor to perform initial diagnosistics.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
          ),
          const SizedBox(height: 48),
          Center(
            child: Icon(Icons.cloud_upload_outlined,
                size: 72, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          Text(
            'You can import later from the dashboard settings using Consolidated Account Statement (CAS) PDF files or broker CSV report files.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                // Navigate to manual screen or proceed
              },
              icon: const Icon(Icons.add),
              label: const Text('Add holding manually'),
            ),
          ),
        ],
      ),
    );
  }
}
