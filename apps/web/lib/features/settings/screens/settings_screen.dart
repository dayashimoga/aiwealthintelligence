import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/common_widgets.dart';

/// Settings screen with theme, notifications, account, and about sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // Profile Card
            GlassCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text('DY', style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimaryContainer,
                    )),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daya', style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                        Text('daya@wealthai.app', style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(128),
                        )),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
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
                    subtitle: Text(themeMode == ThemeMode.dark ? 'Dark' : themeMode == ThemeMode.light ? 'Light' : 'System'),
                    trailing: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 16)),
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.auto_mode, size: 16)),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 16)),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (modes) {
                        ref.read(themeModeProvider.notifier).setThemeMode(modes.first);
                      },
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
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
                    subtitle: const Text('Notify on significant price changes'),
                    value: true,
                    onChanged: (v) {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.warning_amber),
                    title: const Text('Risk Alerts'),
                    subtitle: const Text('Portfolio risk level changes'),
                    value: true,
                    onChanged: (v) {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.newspaper),
                    title: const Text('News Alerts'),
                    subtitle: const Text('Relevant market news for holdings'),
                    value: true,
                    onChanged: (v) {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.auto_awesome),
                    title: const Text('AI Recommendations'),
                    subtitle: const Text('New buy/sell recommendations'),
                    value: true,
                    onChanged: (v) {},
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.account_balance),
                    title: const Text('Dividend Alerts'),
                    subtitle: const Text('Upcoming dividends and ex-dates'),
                    value: false,
                    onChanged: (v) {},
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
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.speed),
                    title: const Text('Analysis Frequency'),
                    subtitle: const Text('Daily'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
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
                    subtitle: const Text('Not configured'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: const Text('Two-Factor Authentication'),
                    subtitle: const Text('Disabled'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.devices),
                    title: const Text('Active Sessions'),
                    subtitle: const Text('1 device'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: AppTheme.spacingMd),

            // About
            _sectionTitle(context, 'About'),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Version'),
                    subtitle: Text('0.1.0 (Build 1)'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('Open Source'),
                    subtitle: const Text('MIT License'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: const Text('Report an Issue'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () {},
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: AppTheme.spacingLg),

            // Logout
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout, color: AppTheme.lossRed),
              label: const Text('Sign Out', style: TextStyle(color: AppTheme.lossRed)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.lossRed),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ).animate().fadeIn(delay: 600.ms),

            const SizedBox(height: AppTheme.spacingXxl),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      )),
    );
  }
}
