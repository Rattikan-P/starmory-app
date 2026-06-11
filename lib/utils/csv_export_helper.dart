import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/vocabulary_model.dart';

/// Result of CSV export operation
enum CsvExportResult {
  success,
  dismissed,
  unavailable,
  error,
}

/// Helper class for exporting vocabulary data to CSV format
class CsvExportHelper {
  /// Export vocabulary list to CSV file and share it
  /// Returns ShareResult to track if user successfully shared or dismissed
  static Future<ShareResult> exportVocabularyToCsv(List<VocabularyModel> vocabularyList) async {
    if (vocabularyList.isEmpty) {
      throw Exception('No vocabulary to export');
    }

    try {
      // Generate CSV content
      final csvContent = _generateVocabularyCsv(vocabularyList);
      print('📄 CSV content generated (${csvContent.length} characters)');
      print('📄 CSV preview:\n${csvContent.split('\n').take(5).join('\n')}');

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().split('.')[0].replaceAll(':', '-');
      final filePath = '${tempDir.path}/starmory_vocabulary_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csvContent);
      print('✅ File saved to: $filePath');

      // Check file exists
      if (!await file.exists()) {
        throw Exception('File was not created');
      }
      print('✅ File exists, size: ${await file.length()} bytes');

      // Read back to verify
      final savedContent = await file.readAsString();
      print('📄 Saved file content (${savedContent.length} chars)');

      // Share the file and get result
      print('📤 Opening share dialog...');
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My vocabulary list from Starmory (${vocabularyList.length} words)',
        subject: 'Starmory Vocabulary Export',
      );
      print('✅ Share dialog closed - status: ${result.status}');

      return result;
    } catch (e) {
      print('❌ Export failed: $e');
      throw Exception('Failed to export vocabulary: ${e.toString()}');
    }
  }

  /// Generate CSV content from vocabulary list
  static String _generateVocabularyCsv(List<VocabularyModel> vocabularyList) {
    // CSV Header
    final buffer = StringBuffer();
    buffer.writeln('Word,Part of Speech,Thai Translation,English Sentence,Thai Sentence,'
        'CEFR Level,Communicative Function,Language Variant,Tags,Created Date');

    // CSV Data rows
    for (final vocab in vocabularyList) {
      // Escape commas and quotes in values
      final word = _escapeCsvField(vocab.word);
      final partOfSpeech = _escapeCsvField(vocab.partOfSpeech);
      final thaiTranslation = _escapeCsvField(vocab.thaiTranslation);
      final englishSentence = _escapeCsvField(vocab.englishSentence);
      final thaiSentence = _escapeCsvField(vocab.thaiSentence);
      final cefrLevel = _escapeCsvField(vocab.cefrLevel);
      final communicativeFunction = _escapeCsvField(vocab.communicativeFunction);
      final languageVariant = _escapeCsvField(vocab.languageVariant);
      final tags = _escapeCsvField(vocab.tags.join('; '));
      final createdDate = _escapeCsvField(
        '${vocab.createdAt.year}-${vocab.createdAt.month.toString().padLeft(2, '0')}-${vocab.createdAt.day.toString().padLeft(2, '0')}',
      );

      buffer.writeln('$word,$partOfSpeech,$thaiTranslation,$englishSentence,'
          '$thaiSentence,$cefrLevel,$communicativeFunction,$languageVariant,'
          '$tags,$createdDate');
    }

    return buffer.toString();
  }

  /// Escape CSV field by wrapping in quotes if contains comma, quote, or newline
  static String _escapeCsvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      // Escape quotes by doubling them and wrap in quotes
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
