import 'package:flutter/services.dart';

/// Thin wrapper over the platform channel in MainActivity.kt that opens
/// Android's "ignore battery optimizations" prompt for this app, so the
/// background server monitor doesn't get killed to save power.
class BatteryOptimization {
  static const _channel = MethodChannel('dev.susiee.lilptero/battery_optimization');

  static Future<bool> isIgnoring() async {
    return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
  }

  static Future<void> requestIgnore() async {
    await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
  }
}
