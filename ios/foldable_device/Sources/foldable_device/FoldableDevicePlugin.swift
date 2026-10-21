import Flutter
import UIKit

/// iOS side of the `foldable_device` EventChannel (Android: FoldableDevicePlugin.kt).
///
/// On iOS 27.1+ the hinge comes from `UIHingeInteraction` (posture/angle) and
/// the fold / camera areas from `UIView.reservedRegions(kind:options:)`:
///   - `.division`  = the fold. Apple: active only while partially open or
///     closed, inactive (but still with a frame) when fully open.
///   - `.occlusion` = areas covering content (e.g. the inner camera).
/// Devices without a hinge (and older iOS) report not foldable with only
/// `isLandscape` live. Re-emits on hinge changes, window resizes (rotation,
/// Split View) and reserved-region changes.
public class FoldableDevicePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  public static func register(with registrar: FlutterPluginRegistrar) {
    FlutterEventChannel(name: "foldable_device", binaryMessenger: registrar.messenger())
      .setStreamHandler(FoldableDevicePlugin())
  }

  private var eventSink: FlutterEventSink?
  private var boundsObservation: NSKeyValueObservation?
  private var sceneObserver: NSObjectProtocol?
  private weak var window: UIWindow?
  /// Latest `UIHinge` (typed `AnyObject` so the class still loads below iOS 27.1).
  private var hinge: AnyObject?
  private var hingeInteraction: UIInteraction?
  private var regionObserver: ReservedRegionObserverView?

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    #if DEBUG
    NSLog("%@", "[Foldable] Dart started listening")
    #endif
    observeWindow()

    // Dart may subscribe before the scene's window exists; attach once it does.
    sceneObserver = NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.observeWindow() }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    boundsObservation = nil
    if let hingeInteraction { window?.removeInteraction(hingeInteraction) }
    hingeInteraction = nil
    regionObserver?.removeFromSuperview()
    regionObserver = nil
    if let sceneObserver { NotificationCenter.default.removeObserver(sceneObserver) }
    sceneObserver = nil
    eventSink = nil
    return nil
  }

  private func observeWindow() {
    guard boundsObservation == nil,
          let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first })
            .first
    else { return }

    self.window = window

    if #available(iOS 27.1, *) {
      // Called with the initial state, then on every hinge change;
      // `hinge` is nil on devices without one.
      let interaction = UIHingeInteraction { [weak self] _, update in
        self?.hinge = update.hinge
        #if DEBUG
        NSLog("%@", "[Foldable] hinge update: \(update.hinge.map { "status=\($0.status.rawValue) angle=\($0.angle)rad" } ?? "no hinge")")
        #endif
        self?.emit()
      }
      window.addInteraction(interaction)
      hingeInteraction = interaction

      // Regions can update after the hinge does, with no notification of
      // their own; this view re-emits whenever UIKit reports they changed.
      let observer = ReservedRegionObserverView(frame: window.bounds)
      observer.onRegionsChanged = { [weak self] in self?.emit() }
      window.insertSubview(observer, at: 0)
      observer.setNeedsUpdateConstraints()
      regionObserver = observer
    }

    // .initial sends the current state right away, like the Android side's
    // first emit.
    boundsObservation = window.layer.observe(\.bounds, options: [.initial, .new]) { [weak self] _, _ in
      self?.emit()
    }
  }

  private func emit() {
    guard let window else { return }
    let bounds = window.bounds
    var event: [String: Any] = [
      "state": "notFoldable",
      "isFoldableDevice": false,
      "isVerticalHinge": false,
      "isLandscape": bounds.width > bounds.height,
    ]

    if #available(iOS 27.1, *), let hinge = hinge as? UIHinge {
      let degrees = hinge.angle * 180 / .pi
      event["isFoldableDevice"] = true
      event["hingeAngle"] = degrees
      event["state"] = Self.state(for: hinge.status, degrees: degrees)

      // Read in the observer's updateConstraints() (so UIKit tracks them).
      // Its frame matches the window, so these are window coordinates in
      // points (= Flutter logical pixels), unlike Android's physical pixels.
      if let fold = regionObserver?.divisions.first {
        event["hingeLeft"] = fold.frame.minX
        event["hingeTop"] = fold.frame.minY
        event["hingeRight"] = fold.frame.maxX
        event["hingeBottom"] = fold.frame.maxY
        event["isVerticalHinge"] = fold.frame.height > fold.frame.width
        event["isFoldActive"] = fold.isActive
      }
      event["occlusions"] = regionObserver?.occlusions.map { region in
        [
          "left": region.frame.minX, "top": region.frame.minY,
          "right": region.frame.maxX, "bottom": region.frame.maxY,
          "isActive": region.isActive,
        ] as [String: Any]
      } ?? []
    }

    #if DEBUG
    NSLog("%@", "[Foldable] emit: \(event)")
    #endif
    eventSink?(event)
  }

  /// Same values as the Android getStateFromAngle; the angle thresholds are
  /// only the fallback for `.unknown`.
  @available(iOS 27.1, *)
  private static func state(for status: UIHinge.Status, degrees: CGFloat) -> String {
    switch status {
    case .closed: return "folded"
    case .fullyOpen: return "unfolded"
    case .partiallyOpen: return "halfOpened"
    default: return degrees <= 0 ? "folded" : degrees >= 175 ? "unfolded" : "halfOpened"
    }
  }
}

/// Invisible, non-interactive full-window view that follows Apple's
/// reserved-region guidance: "UIKit tracks the regions you read in
/// updateConstraints() and runs it again when the regions change." Reading
/// them here is the only change notification iOS offers.
private final class ReservedRegionObserverView: UIView {
  struct Region {
    let frame: CGRect
    let isActive: Bool
  }

  var onRegionsChanged: (() -> Void)?
  /// Includes inactive regions — Apple: they still have a frame, so the
  /// layout can leave room for them and not jump when they activate.
  private(set) var divisions: [Region] = []
  private(set) var occlusions: [Region] = []

  override init(frame: CGRect) {
    super.init(frame: frame)
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    isUserInteractionEnabled = false
    backgroundColor = .clear
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override class var requiresConstraintBasedLayout: Bool { true }

  override func updateConstraints() {
    if #available(iOS 27.1, *) {
      divisions = reservedRegions(kind: .division, options: .includeInactive)
        .map { Region(frame: $0.frame, isActive: $0.isActive) }
      occlusions = reservedRegions(kind: .occlusion, options: .includeInactive)
        .map { Region(frame: $0.frame, isActive: $0.isActive) }
    }
    super.updateConstraints()
    // Emit after the constraint pass instead of in the middle of it.
    DispatchQueue.main.async { [weak self] in self?.onRegionsChanged?() }
  }
}
