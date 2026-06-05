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
