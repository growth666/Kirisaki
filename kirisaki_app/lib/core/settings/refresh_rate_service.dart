import 'package:flutter/services.dart';

import 'settings_service.dart';

/// Applies the user's preference where the platform exposes display modes.
/// Unsupported platforms simply keep the system default.
class RefreshRateService {
  static const _channel = MethodChannel('kirisaki/display');

  static Future<void> apply(RefreshRateMode mode) async {
    try {
      await _channel.invokeMethod<void>('setRefreshRate', mode.name);
    } on MissingPluginException {
      // Windows, iOS and Web use the system display policy.
    } on PlatformException {
      // A device can reject a requested mode (power saving, external display).
    }
  }
}
