import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _repoUrl = 'https://github.com/fazrigading/WheelDeck';

/// Phase 0 stub — full About (avatar, stars count fetch) in Phase 4.
/// Keeps Menu navigation working.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openRepo() async {
    final uri = Uri.parse(_repoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.person, size: 40, color: cs.onPrimaryContainer),
                ),
                const SizedBox(height: 16),
                Text('Fazri Gading', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('Developer', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: Icon(Icons.code, color: cs.primary),
              title: const Text('Source Code'),
              subtitle: const Text('github.com/fazrigading/WheelDeck'),
              trailing: const Icon(Icons.open_in_new, size: 20),
              onTap: _openRepo,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.star_outline, color: cs.primary),
              title: const Text('GitHub Stars'),
              subtitle: const Text('Star the repo if you like WheelDeck'),
              trailing: FilledButton.tonal(
                onPressed: _openRepo,
                child: const Text('Star'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Phase 0 stub — stars badge + count in Phase 4',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}
