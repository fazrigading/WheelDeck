import 'package:flutter/material.dart';

/// Overlay shown after a lifecycle interruption, requiring the user to
/// re-confirm the steering center before input resumes.
class CalibrationOverlay extends StatelessWidget {
  const CalibrationOverlay({
    super.key,
    required this.angle,
    required this.onConfirmed,
  });

  final double angle;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.screen_lock_rotation,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Session interrupted',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'The connection was paused. Please re-confirm\nyour steering center before resuming.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text(
            'Current steering angle: ${angle.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onConfirmed,
            child: const Text('Resume driving'),
          ),
        ],
      ),
    );
  }
}
