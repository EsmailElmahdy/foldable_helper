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
