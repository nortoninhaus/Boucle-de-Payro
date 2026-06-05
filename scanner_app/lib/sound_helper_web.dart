import 'package:web/web.dart' as web;
import 'package:flutter/services.dart';

void _beep(double frequency, double durationSeconds, String type) {
  try {
    // In package:web, we instantiate AudioContext using the constructor
    final audioCtx = web.AudioContext();
    final oscillator = audioCtx.createOscillator();
    final gainNode = audioCtx.createGain();

    oscillator.type = type;
    oscillator.frequency.value = frequency;
    
    gainNode.gain.setValueAtTime(0.08, audioCtx.currentTime);
    // Smooth volume ramp down to prevent audio pops
    gainNode.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + durationSeconds);

    oscillator.connect(gainNode);
    gainNode.connect(audioCtx.destination);

    oscillator.start();
    oscillator.stop(audioCtx.currentTime + durationSeconds);
  } catch (e) {
    // Browsers often block AudioContext before user interaction
    print('Failed to play web synth sound: $e');
  }
}

void playSuccessSound() {
  HapticFeedback.lightImpact();
  _beep(523.25, 0.1, 'sine'); // C5
  Future.delayed(const Duration(milliseconds: 120), () {
    _beep(659.25, 0.15, 'sine'); // E5
  });
}

void playWarningSound() {
  HapticFeedback.mediumImpact();
  _beep(293.66, 0.15, 'triangle'); // D4
  Future.delayed(const Duration(milliseconds: 200), () {
    _beep(293.66, 0.15, 'triangle');
  });
}

void playErrorSound() {
  HapticFeedback.vibrate();
  _beep(140.00, 0.35, 'sawtooth'); // Low buzz
}
