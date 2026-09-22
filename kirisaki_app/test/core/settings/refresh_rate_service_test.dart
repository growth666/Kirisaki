import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/core/settings/refresh_rate_service.dart';
import 'package:kirisaki_app/core/settings/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kirisaki/display');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('all refresh preferences use the display channel', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    for (final mode in RefreshRateMode.values) {
      await RefreshRateService.apply(mode);
    }
    expect(calls.map((call) => call.method), everyElement('setRefreshRate'));
    expect(calls.map((call) => call.arguments), ['system', 'standard', 'high']);
  });

  test('unsupported platforms do not interrupt startup', () async {
    await expectLater(
      RefreshRateService.apply(RefreshRateMode.system),
      completes,
    );
  });

  test('platform rejection does not interrupt the application', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });
    await expectLater(
      RefreshRateService.apply(RefreshRateMode.high),
      completes,
    );
  });
}
