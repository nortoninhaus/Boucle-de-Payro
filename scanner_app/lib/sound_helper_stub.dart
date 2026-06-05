import 'package:flutter/services.dart';

void playSuccessSound() {
  HapticFeedback.lightImpact();
}

void playWarningSound() {
  HapticFeedback.mediumImpact();
}

void playErrorSound() {
  HapticFeedback.vibrate();
}

void downloadCsvFile(String csvContent, String filename) {
  // Sharing or local storage logic for native platforms (unimplemented stub)
  print('Download CSV called on native platform: $filename');
}
