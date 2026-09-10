import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/connection_coordinator.dart';
import '../../about/views/about_screen.dart';
import '../../connection/views/connection_screen.dart';
import '../../donate/views/donate_screen.dart';
import '../../settings/views/settings_screen.dart';

/// M3 Menu hub — shown after onboarding when not in driving session.
/// Logo + title centered, 4 CTAs in thumb zone (bottom 1/3), 8pt grid.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Logo — Icon until asset added; swap to Image.asset('assets/logo.png')
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.sports_motorsports,
                  size: 56,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'WheelDeck',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Phone as wheel & dashboard for PC simulators',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // CTAs — 16dp gaps, full-width, min 48dp height
              _MenuButton(
                icon: Icons.wifi,
                label: 'Connect',
                filled: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConnectionScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _MenuButton(
                icon: Icons.settings,
                label: 'Settings',
                onPressed: () {
                  final coord = context.read<ConnectionCoordinator>();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(coordinator: coord),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _MenuButton(
                icon: Icons.info_outline,
                label: 'About',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _MenuButton(
                icon: Icons.favorite_outline,
                label: 'Donate',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DonateScreen()),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'v0.1.0  •  fazrigading',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    );

    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    final tonalStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    final outlinedStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          style: style,
        ),
      );
    }
    // Use FilledTonal for secondary, Outlined for tertiary — alternating for hierarchy
    // Connect=Filled, Settings=FilledTonal, About/Donate=Outlined per M3 60/30/10
    if (label == 'Settings') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          style: tonalStyle,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: outlinedStyle,
        child: child,
      ),
    );
  }
}
