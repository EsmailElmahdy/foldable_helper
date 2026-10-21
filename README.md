# foldable_device

Foldable support for Flutter on **Android foldables** and the **iPhone Duo (iOS 27.1+)**.
It reports the fold posture, hinge angle and hinge direction, plus the screen areas to keep
content out of (the fold, the camera, and the status pill). Everything comes over one
`EventChannel`.

| Platform | Where the data comes from |
|---|---|
| Android | The hinge-angle sensor (posture and angle) and WindowManager's `FoldingFeature` (fold bounds, direction, `isSeparating`) |
| iOS 27.1+ | `UIHingeInteraction` (status and angle) and `UIView.reservedRegions(kind:options:)` (the fold as `.division`; the camera and status pill as `.occlusion`) |
| Older iOS, non-foldables, other platforms | Reports `notFoldable` |

A runnable demo is in [`example/`](example/).

---

## 1. Install

```sh
flutter pub add foldable_device
```

or in `pubspec.yaml`:

```yaml
dependencies:
  foldable_device: ^0.1.1
```

To use the latest code straight from GitHub instead:

```yaml
dependencies:
  foldable_device:
    git:
      url: https://github.com/EsmailElmahdy/foldable_helper.git
```

Declare it under **`dependencies`**, not `dev_dependencies`. Flutter leaves plugins listed
under `dev_dependencies` out of release builds.

## 2. Platform setup

### iOS
- **Xcode 27.1 or later.** The hinge and reserved-region APIs need the iOS 27.1 SDK. On older iOS
  versions the plugin reports `notFoldable`.
- **Minimum iOS 15.0.** Supported through **CocoaPods** and **Swift Package Manager**.
- **CocoaPods apps:** Flutter's generated `Flutter` pod still says iOS 13.0, which Xcode 27.1
  rejects. Force 15.0 in `ios/Podfile`:
  ```ruby
  platform :ios, '15.0'

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_ios_build_settings(target)
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end
  ```
- No `AppDelegate` code is needed. The plugin registers itself.

### Android
- `minSdk` 24 or higher.
- The activity must be a `LifecycleOwner`. `FlutterActivity` and `FlutterFragmentActivity`
  both are, so no `MainActivity` code is needed.

## 3. Wire it up

```dart
import 'package:flutter/material.dart';
import 'package:foldable_device/foldable_device.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FoldableHelper.initialize();               // 1. start listening to the hinge
  runApp(FoldableScope(                      // 2. once, above MaterialApp
    child: const MaterialApp(home: HomeScreen()),
  ));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    FoldableScope.watch(context);            // 3. rebuild on every fold change

    if (FoldableHelper.isFoldActive) {
      return const Text('two panes, one per side of the fold');
    }
    return const Text('one continuous layout');
  }
}
```

1. **`FoldableHelper.initialize()`**: call it once in `main()`. Without it, no events arrive.
2. **`FoldableScope`**: put it above `MaterialApp`, so every route, sheet and dialog is inside it.
3. **`FoldableScope.watch(context)`**: call it at the top of `build` in any widget whose layout
   depends on the fold. That widget then rebuilds when the posture, hinge angle, orientation
   or regions change.

## 4. Keep content clear of the fold, camera and status pill

### `FoldSafeArea` (widget)

Works like `SafeArea`, but for foldables. It measures where it is on screen and pads its child:

```dart
FoldSafeArea(
  child: ElevatedButton(onPressed: () {}, child: const Text('Tap Me')),
)

FoldSafeArea(avoidFold: false, child: ...)   // camera / status pill only
FoldSafeArea(avoidCamera: false, child: ...) // fold only
```

| Region | When it's avoided | Padding added |
|---|---|---|
| **Camera in use** (active occlusion). The iPhone Duo status pill (time, Wi-Fi) is also active while the status bar is visible. | Always | **Vertical only.** Camera at the top: top padding, so content starts right after it. Camera at the bottom (rotated): bottom padding. Never left or right. |
| **Camera not in use** (inactive occlusion) | Never | None |
| **Active vertical fold**, open like a book | When it crosses the widget | Keeps content on the start side (right padding for left-to-right text, left for right-to-left) |
| **Active horizontal fold**, open like a laptop | When it crosses the widget | Bottom padding that keeps content above the fold |
| **Inactive fold**: fully open | Never | None |

- **`avoidFold`** (default `true`): turns the fold rules on or off.
- **`avoidCamera`** (default `true`): turns the occlusion rules on or off.

Hide the status bar (`SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`) and the status pill's region goes away, so only the camera is padded, and only while it's in use. Rotate so the camera is at the bottom and you get bottom padding only.

**How the edge is chosen:** if the camera is in the top half of the widget, it gets top padding
of `camera.bottom - widget.top`, so content starts right after the camera. If it's in the bottom
half, it gets bottom padding of `widget.bottom - camera.top`. It never adds left or right padding.

The padding settles one frame after a change. It re-measures on fold events and window
resizes, but not while scrolling.

### `FoldableHelper.avoidInsets(rect)` (function)

The same rules as a pure function, for when you already know the rect in global (window)
coordinates:

```dart
final box = context.findRenderObject() as RenderBox;
final insets = FoldableHelper.avoidInsets(
  box.localToGlobal(Offset.zero) & box.size,
  textDirection: Directionality.of(context),
);
```

## 5. API

### `FoldableHelper` (static)

| Member | What it gives you |
|---|---|
| `initialize()` / `dispose()` | Start or stop listening |
| `currentState` | A `FoldableState`: `notFoldable`, `folded`, `halfOpened` or `unfolded` |
| `isFoldable` | Whether the device has a hinge |
| `isFolded`, `isHalfOpened`, `isUnfolded` | Shortcuts for the posture |
| `hingeAngle` | Degrees: 0 = closed, 180 = flat. `null` when there's no hinge. |
| `isVerticalHinge` | The fold runs top to bottom (open like a book) |
| `isLandscape`, `isPortrait` | The window's orientation |
| `fold` | A `FoldRegion?` with the fold's `bounds` and `isActive`. Inactive folds are included. |
| `isFoldActive` | **Apple's rule:** split content at the fold only while this is `true` (partially open) |
| `occlusions` | A `List<FoldRegion>` of areas covering content: the camera and status pill (iOS) |
| `avoidInsets(rect, …)` | Padding that keeps `rect` clear of the regions (see section 4) |
| `isIphoneLayout(shortestSide)` | iPhone Duo: the phone layout only while folded. Elsewhere: `shortestSide < 600`. |
| `changes` | A `ValueNotifier<int>` that ticks on every native event |
| `waitForSettle({quietWindow})` | Completes once events have been quiet for `quietWindow` |

### `FoldRegion`

| Field | What it holds |
|---|---|
| `bounds` | A `Rect` in window coordinates, **logical pixels** on both platforms (the same space as `RenderBox.localToGlobal`) |
| `isActive` | Whether it affects the layout right now. An inactive region still has bounds, so you can leave room for it. |

### Widgets

| Widget | Use |
|---|---|
| `FoldableScope` | Put it once above `MaterialApp`. `FoldableScope.watch(context)` subscribes a widget. |
| `FoldSafeArea` | Pads its child away from the fold, camera and status pill (section 4) |

## 6. How it works

### iOS (`ios/foldable_device/Sources/foldable_device/FoldableDevicePlugin.swift`)
- **Hinge:** a `UIHingeInteraction` on the window. It reports the initial state, then every
  status or angle change. Status mapping: `.closed` → `folded`, `.partiallyOpen` → `halfOpened`,
  `.fullyOpen` → `unfolded`. For `.unknown`, angle thresholds decide (≤0° folded, ≥175° unfolded).
- **Reserved regions:** read inside the `updateConstraints()` of an invisible full-window view,
  following [Apple's guidance](https://developer.apple.com/documentation/uikit/uiview/reservedregion):
  "UIKit tracks the regions you read in `updateConstraints()` and runs it again when the
  regions change." That's the only change signal iOS offers, and it catches regions that
  update *after* the hinge. Both `.division` (the fold) and `.occlusion` (the camera and status
  pill) are read with `.includeInactive`.
- **Window size:** the window's bounds are observed, so rotation and Split View also trigger an event.

### Android (`android/src/main/kotlin/com/esmailelmahdy/foldable_device/FoldableDevicePlugin.kt`)
- **Posture:** from the hinge-angle sensor. 0° = folded, 175° or more = unfolded, anything between = halfOpened.
- **Fold:** bounds and direction come from `WindowInfoTracker` / `FoldingFeature`. The bounds are converted
  to logical pixels, and `isFoldActive` is `isSeparating`.
- **When events are sent:** on sensor changes, layout changes and global layout passes.
- **Tracking lifetime:** it only runs while Dart is listening and an activity is attached.

### Event keys (native → Dart)
`state`, `isFoldableDevice`, `hingeAngle`, `isLandscape`, `isVerticalHinge`,
`hingeLeft/Top/Right/Bottom`, `isFoldActive`, `occlusions` (a list of
`{left, top, right, bottom, isActive}`). All bounds are in logical pixels.

## 7. Debugging

In debug builds, every event is logged with a `[Foldable]` prefix:
- **Dart:** `[Foldable] event: {...} -> state=… angle=… fold=… occlusions=…`
- **iOS (`NSLog`):** `Dart started listening`, `hinge update: status=… angle=…rad`, `emit: [...]`

To read the iOS lines straight from a running simulator:

```sh
xcrun simctl spawn booted log show --last 10m --style compact \
  --predicate 'eventMessage CONTAINS "[Foldable]"'
```

## 8. Tests

```sh
flutter test   # test/avoid_insets_test.dart: padding rules for fold, camera and status pill
```

## 9. Known limits

- **Flutter's own widgets can't see the fold on iOS.** Flutter's iOS engine doesn't fill
  `MediaQuery.displayFeatures`, so `TwoPane` from `split_screen`/`dual_screen` and Flutter's
  built-in dialogs and sheets split 50/50 there. Use `FoldableHelper.fold` and `FoldSafeArea`
  instead. An open Flutter pull request would add this:
  [flutter/flutter#193025](https://github.com/flutter/flutter/pull/193025).
- **No status-bar icon positions.** iOS doesn't give apps the frames of individual status-bar
  icons. The plugin uses the status pill's occlusion region, which covers the time and Wi-Fi icon.
- **Region updates can lag the hinge.** They arrive through `updateConstraints()`, which may be
  slightly after the hinge event.

## License

MIT. See [LICENSE](LICENSE).

