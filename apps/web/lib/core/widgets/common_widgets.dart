import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Glassmorphism-style card with blur effect and subtle border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingMd),
    this.borderRadius = AppTheme.radiusLg,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: gradient ??
                    LinearGradient(
                      colors: isDark
                          ? [
                              Colors.white.withAlpha(13),
                              Colors.white.withAlpha(5),
                            ]
                          : [
                              Colors.white.withAlpha(204),
                              Colors.white.withAlpha(153),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.white.withAlpha(77),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated stat card showing a label, value, and optional change indicator.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.changePositive,
    this.icon,
    this.gradient,
  });

  final String label;
  final String value;
  final String? change;
  final bool? changePositive;
  final IconData? icon;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      gradient: gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(153),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  changePositive == true
                      ? Icons.trending_up
                      : Icons.trending_down,
                  size: 16,
                  color: changePositive == true
                      ? AppTheme.profitGreen
                      : AppTheme.lossRed,
                ),
                const SizedBox(width: 4),
                Text(
                  change!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: changePositive == true
                        ? AppTheme.profitGreen
                        : AppTheme.lossRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}

/// Skeleton loading widget for content placeholders.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A3A) : const Color(0xFFE0E0E0),
      highlightColor:
          isDark ? const Color(0xFF3A3A4A) : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Empty state widget with icon, title, and action button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(77),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.spacingLg),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

/// Error state widget with retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.lossRed,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spacingLg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Responsive grid that adapts columns based on screen width.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = AppTheme.spacingMd,
    this.mobileCols = 1,
    this.tabletCols = 2,
    this.desktopCols = 4,
  });

  final List<Widget> children;
  final double spacing;
  final int mobileCols;
  final int tabletCols;
  final int desktopCols;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int cols;
        if (constraints.maxWidth >= AppTheme.breakpointDesktop) {
          cols = desktopCols;
        } else if (constraints.maxWidth >= AppTheme.breakpointTablet) {
          cols = tabletCols;
        } else {
          cols = mobileCols;
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((child) {
            final width = (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return SizedBox(width: width, child: child);
          }).toList(),
        );
      },
    );
  }
}

/// Action chip for recommendation actions (Buy, Sell, Hold, etc.).
class RecommendationChip extends StatelessWidget {
  const RecommendationChip({
    super.key,
    required this.action,
    this.confidence,
  });

  final String action;
  final double? confidence;

  Color _getColor() {
    switch (action.toLowerCase()) {
      case 'strong_buy':
        return const Color(0xFF00C853);
      case 'buy':
        return const Color(0xFF4CAF50);
      case 'hold':
        return const Color(0xFFFF9800);
      case 'reduce':
        return const Color(0xFFFF5722);
      case 'sell':
        return const Color(0xFFF44336);
      case 'exit':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _getLabel() {
    return action.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getLabel(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (confidence != null) ...[
            const SizedBox(width: 6),
            Text(
              '${confidence!.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color.withAlpha(179),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
