import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/galaxy_screen_background.dart';

class ReviewTab extends ConsumerWidget {
  const ReviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: Center(child: Text('Review'))),
      ),
    );
  }
}
