import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foldable_device/foldable_device.dart';

import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hide the status bar, so only the camera is reported as an occlusion.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Start listening to the native hinge events (Android foldables, iPhone Duo).
  FoldableHelper.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // FoldableScope above the whole app: any widget that calls
    // FoldableScope.watch(context) rebuilds on every fold/hinge change.
    return FoldableScope(
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }
}
