# foldable_device_example

A demo app for the [`foldable_device`](../README.md) plugin.

**What it shows:**
- **`FoldableHelper.initialize()` + `FoldableScope`**: the app is wired up in `lib/main.dart`.
- **`FoldableScope.watch(context)`**: the screen rebuilds on every fold, hinge or orientation change.
- **`FoldSafeArea`**: the green "Tap Me" bar stays on one side of an active fold and out of the
  iPhone Duo status pill (the time and Wi-Fi icon) and the camera.
- **`TwoPane`**: from `split_screen`. It shows two panes while open, side by side for a vertical fold and stacked for a horizontal one.
- **A live status line**: state, hinge angle, fold bounds and occlusions.

## Run

```sh
cd example
flutter run            # pick the iPhone Duo simulator (iOS 27.1) or an Android foldable
```

- **iOS:** needs Xcode 27.1 or later and an iOS 27.1 simulator runtime with the iPhone Duo.
  Change the hinge from the simulator's device controls.
- **Android:** use a foldable emulator (for example the Pixel Fold or 7.6" Fold-in) and its
  posture controls.
