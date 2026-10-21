import 'package:flutter/material.dart';
import 'package:foldable_device/foldable_device.dart';

import 'home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
