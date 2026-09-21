import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/storage_service.dart';
import 'features/dashboard/providers/reels_counter_provider.dart';
import 'platform/native_tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise storage — performs daily reset before the UI renders.
  await StorageService.instance.init();

  // Build and initialise the provider (loads persisted state).
  final provider = ReelsCounterProvider(
    storage: StorageService.instance,
    native: NativeTrackingService.instance,
  );
  await provider.init();

  runApp(ReelsCounterApp(provider: provider));
}
