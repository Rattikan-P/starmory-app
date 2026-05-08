import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../../data/models/vocabulary_model.dart';

/// Vocabulary Result Screen - Display generated vocabulary
/// Shows the AI-generated vocabulary with option to save
class VocabularyResultScreen extends ConsumerWidget {
  final VocabularyModel vocabulary;
  final String imagePath;

  const VocabularyResultScreen({
    super.key,
    required this.vocabulary,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Generated!'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => _saveVocabulary(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original Image
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
              ),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),

            // Vocabulary Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _VocabularyCard(vocabulary: vocabulary),
            ),
            const SizedBox(height: 24),

            // Context Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ContextInfo(vocabulary: vocabulary),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => _saveVocabulary(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.bookmark),
                      label: const Text(
                        'Save to Collection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Regenerate Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _regenerate(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C63FF),
                        side: const BorderSide(color: Color(0xFF6C63FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Generate Different Word',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Back to Home Button
                  TextButton(
                    onPressed: () => Navigator.popUntil(
                      context,
                      (route) => route.isFirst,
                    ),
                    child: Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveVocabulary(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vocabularyStateProvider.notifier);
    notifier.addVocabulary(vocabulary);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Saved to collection!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Navigate back to home
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _regenerate(BuildContext context) {
    Navigator.pop(context);
    // Go back to AI options to regenerate
  }
}

class _VocabularyCard extends StatelessWidget {
  final VocabularyModel vocabulary;

  const _VocabularyCard({required this.vocabulary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9B8CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word
          Text(
            vocabulary.word,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Part of Speech & Thai Translation
          Row(
            children: [
              _InfoChip(
                label: vocabulary.partOfSpeech,
                icon: Icons.category,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                label: vocabulary.thaiTranslation,
                icon: Icons.translate,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // English Sentence
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vocabulary.englishSentence,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  vocabulary.thaiSentence,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextInfo extends StatelessWidget {
  final VocabularyModel vocabulary;

  const _ContextInfo({required this.vocabulary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Context',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          _ContextRow(
            label: 'CEFR Level',
            value: vocabulary.cefrLevel,
            icon: Icons.school,
          ),
          const SizedBox(height: 8),
          _ContextRow(
            label: 'Function',
            value: vocabulary.communicativeFunction,
            icon: Icons.chat_bubble,
          ),
          const SizedBox(height: 8),
          _ContextRow(
            label: 'Variant',
            value: vocabulary.languageVariant,
            icon: Icons.language,
          ),
        ],
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ContextRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
