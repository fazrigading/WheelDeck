import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _links = [
  (label: 'Buy Me a Coffee', url: 'https://buymeacoffee.com/fazrigading', icon: Icons.coffee),
  (label: 'PayPal', url: 'https://paypal.me/fazrigading', icon: Icons.payments),
  (label: 'Ko-fi', url: 'https://ko-fi.com/fazrigading', icon: Icons.favorite),
];

/// Phase 0 stub — polish in Phase 4.
class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Donate')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.favorite, size: 56, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Support WheelDeck',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Your support keeps the project rolling.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          for (final link in _links) ...[
            Card(
              child: ListTile(
                leading: Icon(link.icon, color: cs.primary),
                title: Text(link.label),
                subtitle: Text(link.url),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => _open(link.url),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
