import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Thresholds that trigger the emergency alarm
const double kCpuAlarmThreshold  = 90.0;
const double kMemAlarmThreshold   = 90.0;
const double kDiskAlarmThreshold  = 90.0;

/// How long to wait between repeated alarms (don't spam every 3s)
const Duration kAlarmCooldown = Duration(seconds: 30);

class AlarmService {
  bool _enabled     = true;          // toggled by hidden button
  bool _playing     = false;
  DateTime? _lastAlarm;

  bool get enabled => _enabled;

  void toggle() => _enabled = !_enabled;

  /// Call this every time fresh data arrives.
  /// Returns the reason string if alarm fired, null otherwise.
  Future<String?> evaluate({
    required double cpuPercent,
    required double memPercent,
    required double diskPercent,
  }) async {
    if (!_enabled) return null;

    // Cooldown guard
    if (_lastAlarm != null &&
        DateTime.now().difference(_lastAlarm!) < kAlarmCooldown) {
      return null;
    }

    String? reason;
    if (cpuPercent  >= kCpuAlarmThreshold)  reason = 'CPU ${cpuPercent.toStringAsFixed(0)}%';
    if (memPercent  >= kMemAlarmThreshold)  reason = '${reason != null ? "$reason · " : ""}MEM ${memPercent.toStringAsFixed(0)}%';
    if (diskPercent >= kDiskAlarmThreshold) reason = '${reason != null ? "$reason · " : ""}DISK ${diskPercent.toStringAsFixed(0)}%';

    if (reason == null) return null;

    _lastAlarm = DateTime.now();
    await _fire();
    return reason;
  }

  Future<void> _fire() async {
    if (_playing) return;
    _playing = true;

    // Vibrate pattern: long-short-long for "alarm"
    try {
      HapticFeedback.vibrate();
    } catch (_) {}

    // Play system alarm sound — only supported on Android/iOS
    // flutter_ringtone_player has no Windows implementation
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await FlutterRingtonePlayer().playAlarm(
          looping: false,
          volume: 1.0,
          asAlarm: true,           // forces STREAM_ALARM → ignores silent mode
        );

        // Stop after 5 seconds automatically
        await Future.delayed(const Duration(seconds: 5));
        await FlutterRingtonePlayer().stop();
      }
    } catch (e) {
      debugPrint('AlarmService error: $e');
    } finally {
      _playing = false;
    }
  }

  void stop() {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        FlutterRingtonePlayer().stop();
      }
    } catch (_) {}
    _playing = false;
  }
}
