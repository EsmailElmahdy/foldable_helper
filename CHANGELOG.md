## 1.0.1

* Fix: the README screenshots now load on pub.dev. Image links point to a fixed GitHub commit.
* The Example tab now shows the full walkthrough (`example/example.md`): screenshots,
  `pubspec.yaml`, `main.dart` and `home_screen.dart`, instead of only `main.dart`.

## 1.0.0

* First stable release on pub.dev.
* Example app updated: `FoldSafeArea` around the whole body, a hidden status bar, two panes only
  for a vertical (book) fold, and a live status line.
* Screenshots from the iPhone Duo simulator in `doc/screenshots/` (also shown in the pub.dev
  gallery) and a demo video in `doc/demo.mp4` on GitHub.
* Android package renamed to `com.esmailelmahdy.foldable_device`.

## 0.1.1

* MIT license, pub.dev metadata (topics, issue tracker) and podspec details.
* The example's full `pubspec.yaml`, `main.dart` and `home_screen.dart` are now shown on the pub.dev Example tab (`example/README.md`).
* **`avoidInsets` / `FoldSafeArea`:** camera (occlusion) padding is now **vertical only**. A camera
  at the top gives top padding, so content starts right after it; a camera at the bottom (rotated)
  gives bottom padding. Before, the padding was always left or right.
* Only **active** occlusions are padded. That means the camera only while it's in use, and the
  status pill only while the status bar is visible. Before, an inactive camera was also padded
  while folded.

## 0.1.0

* **Posture, hinge angle, hinge direction and window orientation:** Android (hinge sensor and
  WindowManager) and iPhone Duo (iOS 27.1 `UIHingeInteraction`).
* **iOS reserved regions:** the fold (`.division`) and the camera / status pill (`.occlusion`),
  updated through `updateConstraints()` as Apple recommends.
* **`FoldRegion`**, **`FoldableHelper.fold`**, **`isFoldActive`**, **`occlusions`** and **`avoidInsets()`**.
* **`FoldSafeArea`**: a widget that pads content away from the fold, camera and status pill.
* **`FoldableScope`**: rebuilds subscribed widgets on every fold change.
* **Logical-pixel bounds** on both platforms.
* **iOS packaging:** CocoaPods and Swift Package Manager, with a minimum of iOS 15.0.
* **Example app** in `example/`.
