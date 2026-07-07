import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/portfolio_providers.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

/// Settings screen with theme, notifications, security (MFA, Passkeys, active sessions), and API configuration.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Local notification switches
  bool _priceAlerts = true;
  bool _riskAlerts = true;
  bool _newsAlerts = true;
  bool _aiRecs = true;
  bool _dividendAlerts = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = theme.brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: profileAsync.when(
          data: (user) {
            final avatarChar =
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U';

            return ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              children: [
                // Profile Card
                GlassCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          avatarChar,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName.isNotEmpty
                                  ? user.fullName
                                  : 'WealthAI User',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              user.email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withAlpha(128),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: AppTheme.spacingLg),

                // Appearance
                _sectionTitle(context, 'Appearance'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.dark_mode),
                        title: const Text('Theme'),
                        subtitle: Text(themeMode == ThemeMode.dark
                            ? 'Dark'
                            : themeMode == ThemeMode.light
                                ? 'Light'
                                : 'System'),
                        trailing: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode, size: 16)),
                            ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.auto_mode, size: 16)),
                            ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode, size: 16)),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (modes) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(modes.first);
                          },
                          style: const ButtonStyle(
                              visualDensity: VisualDensity.compact),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: AppTheme.spacingMd),

                // Notifications
                _sectionTitle(context, 'Notifications'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.price_change),
                        title: const Text('Price Alerts'),
                        subtitle:
                            const Text('Notify on significant price changes'),
                        value: _priceAlerts,
                        onChanged: (v) => setState(() => _priceAlerts = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.warning_amber),
                        title: const Text('Risk Alerts'),
                        subtitle: const Text('Portfolio risk level changes'),
                        value: _riskAlerts,
                        onChanged: (v) => setState(() => _riskAlerts = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.newspaper),
                        title: const Text('News Alerts'),
                        subtitle:
                            const Text('Relevant market news for holdings'),
                        value: _newsAlerts,
                        onChanged: (v) => setState(() => _newsAlerts = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.auto_awesome),
                        title: const Text('AI Recommendations'),
                        subtitle: const Text('New buy/sell recommendations'),
                        value: _aiRecs,
                        onChanged: (v) => setState(() => _aiRecs = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.account_balance),
                        title: const Text('Dividend Alerts'),
                        subtitle: const Text('Upcoming dividends and ex-dates'),
                        value: _dividendAlerts,
                        onChanged: (v) => setState(() => _dividendAlerts = v),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: AppTheme.spacingMd),

                // AI Configuration
                _sectionTitle(context, 'AI Configuration'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.auto_awesome),
                        title: const Text('AI Provider'),
                        subtitle: const Text('OpenAI (GPT-4o-mini)'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showAiProviderDialog(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.vpn_key_outlined),
                        title: const Text('Model API Keys'),
                        subtitle: const Text(
                            'Configure OpenAI / Anthropic credentials'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showApiKeysDialog(context),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: AppTheme.spacingMd),

                // Security
                _sectionTitle(context, 'Security'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.fingerprint),
                        title: const Text('Passkeys'),
                        subtitle: Text(user.passkeys.isNotEmpty
                            ? 'Configured (${user.passkeys.length})'
                            : 'Not configured'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showPasskeysDialog(context, user),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.security),
                        title: const Text('Two-Factor Authentication'),
                        subtitle: Text(
                            user.mfaEnabled ? 'Enabled (TOTP)' : 'Disabled'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showTotpDialog(context, user),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.devices),
                        title: const Text('Active Sessions'),
                        subtitle: Text(
                            '${user.trustedDevices.isNotEmpty ? user.trustedDevices.length : 1} active devices'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showDevicesDialog(context, user),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: AppTheme.spacingLg),

                // Account Deletion & Logout Options
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.logout, color: AppTheme.lossRed),
                        title: const Text('Sign Out',
                            style: TextStyle(color: AppTheme.lossRed)),
                        onTap: () async {
                          await ref
                              .read(authStateProvider.notifier)
                              .logout();
                          // router redirect fires automatically via AuthStatus
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_outlined,
                            color: AppTheme.lossRed),
                        title: const Text('Delete Account',
                            style: TextStyle(color: AppTheme.lossRed)),
                        subtitle: const Text(
                            'Permanently purge profile and portfolios',
                            style: TextStyle(fontSize: 11)),
                        onTap: () => _showDeleteConfirmDialog(context),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: AppTheme.spacingXxl),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.lossRed),
                const SizedBox(height: 16),
                const Text('Failed to load profile settings'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  // AI Provider selection
  void _showAiProviderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('AI Analytics Provider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('OpenAI GPT-4o-mini (Recommended)'),
                value: 'openai',
                groupValue: 'openai',
                onChanged: (_) => Navigator.pop(context),
              ),
              RadioListTile<String>(
                title: const Text('Anthropic Claude 3.5 Sonnet'),
                value: 'claude',
                groupValue: 'openai',
                onChanged: null,
              ),
              RadioListTile<String>(
                title: const Text('DeepSeek Coder V2'),
                value: 'deepseek',
                groupValue: 'openai',
                onChanged: null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Secure API key configuration input dialog
  void _showApiKeysDialog(BuildContext context) async {
    final storage = ref.read(secureStorageProvider);
    final oaiController =
        TextEditingController(text: await storage.read(key: 'openai_api_key'));
    final antController = TextEditingController(
        text: await storage.read(key: 'anthropic_api_key'));

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configure Model API Keys'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'API keys are stored securely locally in the device keychain and used to execute no-cost analysis tasks.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: oaiController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'OpenAI API Key',
                  hintText: 'sk-...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: antController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Anthropic API Key',
                  hintText: 'sk-ant-...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await storage.write(
                    key: 'openai_api_key', value: oaiController.text);
                await storage.write(
                    key: 'anthropic_api_key', value: antController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('API keys updated successfully')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Passkey mock orchestration dialog
  void _showPasskeysDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Passkeys Setup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.passkeys.isNotEmpty
                    ? 'You have ${user.passkeys.length} passkeys registered on this account.'
                    : 'Register a passkey to secure logins using your device fingerprint or face recognition.',
              ),
              const SizedBox(height: 12),
              if (user.passkeys.isNotEmpty)
                const Text(
                  'Configured credential handles:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ...user.passkeys.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'ID: ${p.credentialId.substring(0, math.min(10, p.credentialId.length))}... (Created: ${p.createdAt.substring(0, 10)})',
                    style:
                        const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _runPasskeyOrchestration(context);
              },
              child: const Text('Register New Passkey'),
            ),
          ],
        );
      },
    );
  }

  void _runPasskeyOrchestration(BuildContext context) async {
    final repo = ref.read(authRepositoryProvider);
    final optionsRes = await repo.passkeyRegisterOptions();

    optionsRes.when(
      success: (data) async {
        if (!context.mounted) return;

        // Show signature simulation challenge dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Passkey Verification'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint, size: 48, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                    'Challenge received: ${data['challenge']?.substring(0, 12)}...'),
                const SizedBox(height: 8),
                const Text(
                  'Verify fingerprint or face recognition prompt on your device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final verifyRes = await repo.passkeyRegisterVerify(
                    credentialId: 'cred_${math.Random().nextInt(1000000)}',
                    clientDataJson: 'client_data_mock',
                    authenticatorData: 'auth_data_mock',
                    signature: 'sig_mock',
                  );

                  verifyRes.when(
                    success: (msg) {
                      ref.invalidate(userProfileProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    },
                    failure: (err, _) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Verification failed: $err'),
                              backgroundColor: AppTheme.lossRed),
                        );
                      }
                    },
                  );
                },
                child: const Text('Simulate Bio Verify'),
              ),
            ],
          ),
        );
      },
      failure: (err, _) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to load WebAuthn options: $err'),
                backgroundColor: AppTheme.lossRed),
          );
        }
      },
    );
  }

  // TOTP MFA Configuration setup
  void _showTotpDialog(BuildContext context, User user) {
    if (user.mfaEnabled) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disable Two-Factor Authentication'),
          content: const Text(
              'Are you sure you want to disable TOTP multi-factor security? Logins will only require your password.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.lossRed),
              onPressed: () async {
                Navigator.pop(context);
                final res =
                    await ref.read(authRepositoryProvider).disableTotp();
                res.when(
                  success: (msg) {
                    ref.invalidate(userProfileProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
                  failure: (err, _) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Failed to disable: $err'),
                            backgroundColor: AppTheme.lossRed),
                      );
                    }
                  },
                );
              },
              child: const Text('Disable'),
            ),
          ],
        ),
      );
    } else {
      _runTotpEnableSetup(context);
    }
  }

  void _runTotpEnableSetup(BuildContext context) async {
    final repo = ref.read(authRepositoryProvider);
    final setupRes = await repo.setupTotp();

    setupRes.when(
      success: (data) {
        if (!context.mounted) return;
        final secret = data['secret'] as String? ?? '';
        final otpController = TextEditingController();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Setup Multi-Factor Auth'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    '1. Enter this secret key in your Google Authenticator or Microsoft Authenticator app:'),
                const SizedBox(height: 10),
                SelectableText(
                  secret,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: Colors.blue),
                ),
                const SizedBox(height: 16),
                const Text('2. Input the generated 6-digit verification code:'),
                const SizedBox(height: 8),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final verifyRes =
                      await repo.enableTotp(code: otpController.text);
                  verifyRes.when(
                    success: (backupCodes) {
                      ref.invalidate(userProfileProvider);
                      _showBackupCodesDialog(context, backupCodes);
                    },
                    failure: (err, _) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Verification code invalid: $err'),
                              backgroundColor: AppTheme.lossRed),
                        );
                      }
                    },
                  );
                },
                child: const Text('Verify and Enable'),
              ),
            ],
          ),
        );
      },
      failure: (err, _) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to load TOTP setup details: $err'),
                backgroundColor: AppTheme.lossRed),
          );
        }
      },
    );
  }

  void _showBackupCodesDialog(BuildContext context, List<String> codes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Save Backup Codes'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Multi-factor authentication is active. Save these emergency backup codes to restore access in case you lose your device:'),
            const SizedBox(height: 16),
            ...codes.map(
              (c) => Text(
                c,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Have Saved Them'),
          ),
        ],
      ),
    );
  }

  // Active Sessions & trusted devices
  void _showDevicesDialog(BuildContext context, User user) {
    if (user.trustedDevices.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Active Sessions'),
          content: const Text('No other active device sessions registered.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Active Sessions'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: user.trustedDevices.length,
              itemBuilder: (context, index) {
                final d = user.trustedDevices[index];
                return ListTile(
                  title: Text(d.name.isNotEmpty ? d.name : 'Unknown Device'),
                  subtitle: Text(
                      'Logged in: ${d.registeredAt.toIso8601String().substring(0, 10)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppTheme.lossRed),
                    onPressed: () async {
                      Navigator.pop(context);
                      final repo = ref.read(authRepositoryProvider);
                      final res = await repo.revokeDevice(deviceId: d.deviceId);
                      res.when(
                        success: (msg) {
                          ref.invalidate(userProfileProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(msg)));
                          }
                        },
                        failure: (err, _) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Failed to revoke session: $err'),
                                  backgroundColor: AppTheme.lossRed),
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        );
      },
    );
  }

  // Account permanent deletion confirm
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.lossRed),
              SizedBox(width: 10),
              Text('Delete Account Forever?'),
            ],
          ),
          content: const Text(
            'This action is irreversible. All portfolios, uploaded statement logs, transaction histories, and credentials will be purged permanently from the server databases.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.lossRed),
              onPressed: () async {
                Navigator.pop(context);
                final res =
                    await ref.read(authRepositoryProvider).deleteAccount();
                res.when(
                  success: (msg) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(msg)));
                    }
                    // Clear auth state — router redirects to /login.
                    ref.read(authStateProvider.notifier).logout();
                  },
                  failure: (err, _) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Failed to delete account: $err'),
                            backgroundColor: AppTheme.lossRed),
                      );
                    }
                  },
                );
              },
              child: const Text('Purge My Account'),
            ),
          ],
        );
      },
    );
  }
}
