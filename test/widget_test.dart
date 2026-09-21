import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ircmobile/core/services/storage_service.dart';
import 'package:ircmobile/features/dashboard/providers/reels_counter_provider.dart';
import 'package:ircmobile/features/dashboard/screens/dashboard_screen.dart';
import 'package:ircmobile/platform/native_tracking_service.dart';

const MethodChannel _channel = MethodChannel('reels_counter/native');

void _setupMockChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) async {
    switch (call.method) {
      case 'isAccessibilityServiceEnabled':
        return false;
      case 'isOverlayPermissionGranted':
        return false;
      default:
        return null;
    }
  });
}

Future<ReelsCounterProvider> _buildProvider() async {
  SharedPreferences.setMockInitialValues({});
  await StorageService.instance.init();
  final provider = ReelsCounterProvider(
    storage: StorageService.instance,
    native: NativeTrackingService.instance,
  );
  await provider.init();
  return provider;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _setupMockChannel();
  });

  tearDown(() async {
    await StorageService.instance.clearAll();
  });

  testWidgets('DashboardScreen counter starts at 0', (tester) async {
    final provider = await _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<ReelsCounterProvider>.value(
        value: provider,
        child: MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump(); // settle first frame

    // The counter should show "0".
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('DashboardScreen debug increment updates count', (tester) async {
    final provider = await _buildProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<ReelsCounterProvider>.value(
        value: provider,
        child: MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    // Tap the debug increment button.
    await tester.tap(find.byTooltip('Debug: add reel'));
    await tester.pump();

    expect(provider.todayCount, 1);
  });
}
