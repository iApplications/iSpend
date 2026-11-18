import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_surface.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About iSpend')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const SizedBox(
                width: 72,
                height: 72,
                child: Icon(
                  Icons.savings_outlined,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'iSpend',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Version $_version',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Private by design', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'iSpend stores your data locally on your device. It has no account, no advertising, and no normal-use cloud service.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Names and marks', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'Provider names and marks belong to their respective owners. iSpend uses original, non-official icon designs and is not affiliated with, endorsed by, or connected to any provider.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
