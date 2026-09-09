import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _links = [
  (
    label: 'Buy Me a Coffee',
    url: 'https://buymeacoffee.com/fazrigading',
    icon: Icons.coffee,
    desc: 'One-time support — the fastest way to say thanks',
    color: Color(0xFFFFDD00),
  ),
  (
    label: 'PayPal',
    url: 'https://paypal.me/fazrigading',
    icon: Icons.payments,
    desc: 'Direct transfer via PayPal',
    color: Color(0xFF003087),
  ),
  (
    label: 'Ko-fi',
    url: 'https://ko-fi.com/fazrigading',
    icon: Icons.favorite,
    desc: 'Support with a monthly or one-off tip',
    color: Color(0xFFe57373),
  ),
];

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
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Donate'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.favorite, size: 36, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text('Support WheelDeck',
              textAlign: TextAlign.center,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Your support keeps the project rolling — open source,\nno ads, built for sim fans.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 32),
          for (final link in _links) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Icon(link.icon, color: cs.onSecondaryContainer),
                ),
                title: Text(link.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(link.desc, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                trailing: FilledButton.tonal(
                  onPressed: () => _open(link.url),
                  child: const Text('Open'),
                ),
                onTap: () => _open(link.url),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Text('Links open externally. Thank you!',
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
