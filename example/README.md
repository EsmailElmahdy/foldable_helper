# foldable_device example

A demo app for the [`foldable_device`](https://pub.dev/packages/foldable_device) plugin.

**What it shows:**
- **`FoldableHelper.initialize()` + `FoldableScope`**: the app is wired up in `lib/main.dart`.
- **`FoldableScope.watch(context)`**: the screen rebuilds on every fold, hinge or orientation change.
- **`FoldSafeArea`**: the green "Tap Me" bar stays on one side of an active fold and out of the
  camera while it's in use.
- **`TwoPane`**: from `split_screen`. It shows two panes while open, side by side for a vertical fold and stacked for a horizontal one.
- **A live status line**: state, hinge angle, fold bounds and occlusions.

## pubspec.yaml

```yaml
name: foldable_device_example
description: "Demo of the foldable_device plugin: fold-aware TwoPane layout and FoldSafeArea."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.10.3

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  split_screen: ^1.0.5
  foldable_device: ^0.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

## lib/main.dart

```dart
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
```

## lib/home_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:foldable_device/foldable_device.dart';
import 'package:split_screen/split_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild this screen whenever the posture, hinge angle or orientation changes.
    FoldableScope.watch(context);

    // Open (half-opened or flat) -> two panes; folded / not foldable -> one.
    final isOpen = FoldableHelper.isUnfolded || FoldableHelper.isHalfOpened;

    return Scaffold(
      appBar: AppBar(title: const Center(child: Text('Foldable Demo'))),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pads the button away from the camera (while in use) and keeps it
          // on one side of an active fold — measured from where it actually
          // is on screen. Try avoidFold: false / avoidCamera: false.
          FoldSafeArea(
            child: InkWell(
              onTap: () {},
              child: Container(
                color: Colors.green,
                width: double.infinity,
                child: const Text('Tap Me', style: TextStyle(fontSize: 48)),
              ),
            ),
          ),

          // Live values from the plugin.
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'state: ${FoldableHelper.currentState.name}   '
              'angle: ${FoldableHelper.hingeAngle?.toStringAsFixed(0) ?? '-'}°   '
              'vertical hinge: ${FoldableHelper.isVerticalHinge}   '
              'fold active: ${FoldableHelper.isFoldActive}\n'
              'fold: ${FoldableHelper.fold?.bounds}\n'
              'occlusions: ${FoldableHelper.occlusions.map((o) => '${o.bounds} active=${o.isActive}').join(', ')}',
            ),
          ),

          // TwoPane / Container need a bounded height inside a Column.
          Expanded(
            child: isOpen
                ? TwoPane(
                    // Vertical fold (book pose) -> panes side by side,
                    // horizontal fold (laptop pose) -> panes on top of each other.
                    direction: FoldableHelper.isVerticalHinge ? Axis.horizontal : Axis.vertical,
                    panePriority: TwoPanePriority.both,
                    startPane: const ColoredBox(color: Colors.blueAccent),
                    endPane: const ColoredBox(color: Colors.red),
                  )
                : Container(color: Colors.yellow),
          ),
        ],
      ),
    );
  }
}
```

## Run

```sh
cd example
flutter run            # pick the iPhone Duo simulator (iOS 27.1) or an Android foldable
```

- **iOS:** needs Xcode 27.1 or later and an iOS 27.1 simulator runtime with the iPhone Duo.
  Change the hinge from the simulator's device controls.
- **Android:** use a foldable emulator (for example the Pixel Fold or 7.6" Fold-in) and its
  posture controls.

Inside this repo, the example uses `foldable_device: path: ../` so it runs against the local code.
