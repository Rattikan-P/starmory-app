import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Get the test data directory
Directory getTestDataDir() {
  final currentDir = Directory.current.path;
  return Directory('$currentDir/test/test_data/images');
}

/// Load a test image file by name
Future<Uint8List> loadTestImage(String filename) async {
  final testDataDir = getTestDataDir();
  final file = File('${testDataDir.path}/$filename');

  if (!await file.exists()) {
    throw FileSystemException('Test image not found', file.path);
  }

  return await file.readAsBytes();
}

/// Check if a test image exists
Future<bool> testImageExists(String filename) async {
  final testDataDir = getTestDataDir();
  final file = File('${testDataDir.path}/$filename');
  return await file.exists();
}

/// Test helper function to print formatted output for Test Record
void printTestOutput({
  required String testId,
  required String description,
  required Map<String, dynamic> input,
  required Map<String, dynamic> expectedOutput,
  required Map<String, dynamic> actualOutput,
}) {
  final separator = '=' * 60;
  print('');
  print(separator);
  print('TEST ID: $testId');
  print('Description: $description');
  print('-' * 60);
  print('Input:');
  input.forEach((key, value) {
    print('  $key: $value');
  });
  print('-' * 60);
  print('Expected Output:');
  print(const JsonEncoder.withIndent('  ').convert(expectedOutput));
  print('-' * 60);
  print('Actual Output:');
  print(const JsonEncoder.withIndent('  ').convert(actualOutput));
  print('-' * 60);
  print('Status: ${_compareJson(expectedOutput, actualOutput) ? "✓ PASS" : "✗ FAIL"}');
  print(separator);
  print('');
}

/// Test helper for simple input/output
void printTestOutputSimple({
  required String testId,
  required String description,
  required String input,
  required Map<String, dynamic> expectedOutput,
  required Map<String, dynamic> actualOutput,
}) {
  printTestOutput(
    testId: testId,
    description: description,
    input: {'input': input},
    expectedOutput: expectedOutput,
    actualOutput: actualOutput,
  );
}

/// Compare two JSON objects for equality
bool _compareJson(Map<String, dynamic> expected, Map<String, dynamic> actual) {
  try {
    return const JsonEncoder().convert(expected) ==
        const JsonEncoder().convert(actual);
  } catch (e) {
    return false;
  }
}

/// Print test header
void printTestHeader(String testName) {
  print('');
  print('╔${'═' * 58}╗');
  print('║ $testName${' ' * (58 - testName.length)}║');
  print('╚${'═' * 58}╝');
  print('');
}

/// Print test summary
void printTestSummary(Map<String, dynamic> results) {
  final separator = '=' * 60;
  print('');
  print(separator);
  print('TEST SUMMARY');
  print(separator);
  print('Total Tests: ${results['total']}');
  print('Passed: ${results['passed']}');
  print('Failed: ${results['failed']}');
  print('Pass Rate: ${results['passRate']}%');
  print(separator);
  print('');
}
