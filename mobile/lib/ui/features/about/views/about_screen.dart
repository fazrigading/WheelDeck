import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _repoUrl = 'https://github.com/fazrigading/WheelDeck';
const _apiUrl = 'https://api.github.com/repos/fazrigading/WheelDeck';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int? _stars;
  bool _loadingStars = true;

  @override
  void initState() {
    super.initState();
    _fetchStars();
  }

  Future<void> _fetchStars() async {
    try {
      final res = await http.get(Uri.parse(_apiUrl)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final count = data['stargazers_count'] as int?;
        if (mounted) setState(() => _stars = count);
      }
    } catch (_) {
      // offline / rate-limit — badge stays placeholder
    } finally {
      if (mounted) setState(() => _loadingStars = false);
    }
  }

  Future<void> _openRepo(BuildContext context) async {
    final uri = Uri.parse(_repoUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        final fallback = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallback && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open $_repoUrl')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $_repoUrl: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.person, size: 44, color: cs.onPrimaryContainer),
                ),
                const SizedBox(height: 16),
                Text('Fazri Gading', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('Developer • WheelDeck', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Text('Turning phones into wheels for PC simulators.',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.code, color: cs.onSecondaryContainer),
              ),
              title: const Text('Source Code', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('github.com/fazrigading/WheelDeck'),
              trailing: FilledButton.tonalIcon(
                onPressed: () => _openRepo(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.star, color: cs.onTertiaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GitHub Stars', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        _loadingStars
                            ? SizedBox(
                                height: 16,
                                width: 80,
                                child: LinearProgressIndicator(
                                  backgroundColor: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star, size: 14, color: cs.onPrimaryContainer),
                                        const SizedBox(width: 4),
                                        Text(
                                          _stars != null ? '$_stars' : '—',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('stars',
                                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openRepo(context),
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('Star'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('MIT Licensed • v0.1.0',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }
}
