import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Placeholder home screen — first increment of the real home.
///
/// The official home has: hero carousel, continue-watching row, next-up row,
/// and catalog rows from addons. This scaffold establishes the layout shell
/// and focus behavior; data wiring lands with the catalog repository.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Nuvio',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: NuvioColors.text,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Home — catalog rows land here',
              style: TextStyle(color: NuvioColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
