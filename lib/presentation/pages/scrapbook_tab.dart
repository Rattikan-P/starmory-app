import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScrapbookTab extends ConsumerWidget {
  const ScrapbookTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(child: Center(child: Text('Scrapbook'))),
    );
  }
}
