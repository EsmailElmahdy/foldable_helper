import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A reserved area of the window: the fold, or something covering content
/// (e.g. the iPhone Duo inner camera). [bounds] is in window coordinates,
/// logical pixels (same space as `RenderBox.localToGlobal`).
class FoldRegion {
  const FoldRegion(this.bounds, {required this.isActive});

  final Rect bounds;

  /// Whether it currently affects the layout. iOS: the fold is active only
  /// while partially open or closed; an inactive region still has [bounds],
  /// so you can leave room for it and avoid a jump when it activates.
  final bool isActive;

  static FoldRegion? _parse(Object? l, Object? t, Object? r, Object? b, Object? isActive) {
    if (l is! num || t is! num || r is! num || b is! num) return null;
    return FoldRegion(
      Rect.fromLTRB(l.toDouble(), t.toDouble(), r.toDouble(), b.toDouble()),
      isActive: isActive == true,
    );
  }

  @override
  String toString() => 'FoldRegion($bounds, active: $isActive)';
}

enum FoldableState {
  notFoldable,
  folded,
  halfOpened,
  unfolded,
}

class FoldableHelper {
  static const EventChannel _channel =
  EventChannel('foldable_device');

  static FoldableState _currentState =
      FoldableState.notFoldable;

  static bool _isFoldableDevice = false;

  static double? _hingeAngle;

  static bool _isLandscape = false;

  static bool _isVerticalHinge = false;

  static FoldRegion? _fold;

  static List<FoldRegion> _occlusions = const [];

  /// The fold area (iOS: `reservedRegions(kind: .division)`, Android:
  /// FoldingFeature), including inactive — null when the device has none.
  static FoldRegion? get fold => _fold;

  /// Areas covering content, e.g. the iPhone Duo inner camera (iOS only;
  /// includes inactive ones). Keep important content out of their bounds.
  static List<FoldRegion> get occlusions => _occlusions;

  /// Apple's rule: split content at the fold only while it's active
  /// (partially open / closed). Fully open → one continuous layout.
  static bool get isFoldActive => _fold?.isActive ?? false;

  /// Padding that keeps content laid out in [area] (global/window
  /// coordinates, logical px) clear of reserved regions:
  ///   - [occlusions] overlapping [area] -> vertical padding only, never
  ///     left/right: a region in the top half of [area] -> top padding so the
  ///     content starts right after it; in the bottom half (e.g. camera at
  ///     the bottom after rotating) -> bottom padding so it ends before it:
  ///       * only ACTIVE ones — they cover content right now: the camera
  ///         while it's in use (and the iPhone Duo status pill, when the status
  ///         bar is visible). A camera that isn't in use is ignored;
  ///   - an active vertical fold crossing [area] -> padding that keeps the
  ///     content on the start side (Apple: keep each view on one side);
  ///   - an active horizontal fold crossing [area] -> bottom padding that
  ///     keeps it above the fold.
  /// Prefer the [FoldSafeArea] widget, which measures [area] itself.
  static EdgeInsets avoidInsets(
    Rect area, {
    TextDirection textDirection = TextDirection.ltr,
    bool avoidCamera = true,
    bool avoidFold = true,
  }) {
    var left = 0.0, top = 0.0, right = 0.0, bottom = 0.0;

    if (avoidCamera) {
      for (final camera in _occlusions) {
        if (!camera.isActive) continue; // camera not in use -> no padding
        final r = camera.bounds;
        if (!r.overlaps(area)) continue;
        if (r.center.dy < area.center.dy) {
          top = math.max(top, r.bottom - area.top); // start after the camera
        } else {
          bottom = math.max(bottom, area.bottom - r.top); // end before it
        }
      }
    }

    final fold = _fold;
    if (avoidFold && fold != null && fold.isActive && fold.bounds.overlaps(area)) {
      final r = fold.bounds;
      if (_isVerticalHinge) {
        if (textDirection == TextDirection.ltr) {
          right = math.max(right, area.right - r.left);
        } else {
          left = math.max(left, r.right - area.left);
        }
      } else {
        bottom = math.max(bottom, area.bottom - r.top);
      }
    }

    return EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);
  }

  /// Raw hinge-angle sensor reading in degrees.
  ///
  /// 0   = closed
  /// 180 = flat/open
  static double? get hingeAngle => _hingeAngle;

  /// Whether the current window is in landscape orientation.
  ///
  /// This is purely "is the window wider than tall" and says nothing about
  /// which way the hinge runs — two foldables with differently-shaped inner
  /// displays (e.g. Z Fold vs Pixel Fold) can report opposite values here for
  /// the same physical "open like a book" posture. Prefer [isVerticalHinge]
  /// for anything that actually depends on hinge direction.
  static bool get isLandscape => _isLandscape;

  /// Whether the current window is in portrait orientation.
  static bool get isPortrait => !_isLandscape;

  /// Whether the physical hinge runs vertically (splits the screen into a
  /// left half and a right half), regardless of the window's own aspect
  /// ratio. This is the hardware-agnostic signal for choosing a side-by-side
  /// pane layout — unlike [isLandscape]/[isPortrait], it doesn't flip between
  /// devices whose inner display happens to be shaped differently.
  static bool get isVerticalHinge => _isVerticalHinge;

  static StreamSubscription<Map<Object?, Object?>>? _subscription;

  /// Bumped on every posture/orientation update so widgets can rebuild.
  static final ValueNotifier<int> changes =
  ValueNotifier<int>(0);

  static FoldableState get currentState => _currentState;

  /// Whether the hardware itself supports folding.
  static bool get isFoldable => _isFoldableDevice;

  static bool get isHalfOpened =>
      _currentState == FoldableState.halfOpened;

  static bool get isUnfolded =>
      _currentState == FoldableState.unfolded;

  static bool get isFolded =>
      _currentState == FoldableState.folded;

  /// Whether to use the iPhone layout (vs the iPad one) for [shortestSide].
  ///
  /// On iPhone Duo the posture decides: iPhone layout only while folded,
  /// iPad layout once half-opened or unfolded (its inner display is under
  /// the 600 cutoff). Android foldables keep the size rule — book-style inner
  /// displays are already >= 600, and flips must stay on the iPhone layout.
  ///
  /// Prefer `context.isIphone`; call this directly only where a context
  /// can't subscribe (initState).
  static bool isIphoneLayout(double shortestSide) =>
      Platform.isIOS && _isFoldableDevice ? isFolded : shortestSide < 600;

  static Stream<Map<Object?, Object?>> get _eventStream =>
      _channel
          .receiveBroadcastStream()
          .cast<Map<Object?, Object?>>();

  static FoldableState _parseState(Object? value) {
    switch (value) {
      case 'folded':
        return FoldableState.folded;

      case 'halfOpened':
        return FoldableState.halfOpened;

      case 'unfolded':
        return FoldableState.unfolded;

      default:
        return FoldableState.notFoldable;
    }
  }

  static void initialize() {
    _subscription ??= _eventStream.listen(
          (event) {
        _currentState =
            _parseState(event['state']);

        _isFoldableDevice =
            event['isFoldableDevice'] == true;

        _hingeAngle =
            (event['hingeAngle'] as num?)?.toDouble();

        _isLandscape =
            event['isLandscape'] == true;

        _isVerticalHinge =
            event['isVerticalHinge'] == true;

        _fold = FoldRegion._parse(event['hingeLeft'], event['hingeTop'],
            event['hingeRight'], event['hingeBottom'], event['isFoldActive']);

        _occlusions = [
          for (final o in (event['occlusions'] as List<Object?>? ?? const []))
            if (o is Map<Object?, Object?>)
              FoldRegion._parse(o['left'], o['top'], o['right'], o['bottom'], o['isActive']),
        ].whereType<FoldRegion>().toList();

        debugPrint('[Foldable] event: $event -> state=$_currentState '
            'foldable=$_isFoldableDevice angle=$_hingeAngle '
            'landscape=$_isLandscape verticalHinge=$_isVerticalHinge '
            'fold=$_fold occlusions=$_occlusions');

        changes.value++;

      },
      onError: (error) {
        debugPrint('[Foldable] channel error: $error');
        _currentState = FoldableState.notFoldable;
        _isFoldableDevice = false;
        _hingeAngle = null;
        _isLandscape = false;
        _isVerticalHinge = false;
        _fold = null;
        _occlusions = const [];

        changes.value++;
      },
    );
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
  static Future<void> waitForSettle({
    Duration quietWindow = const Duration(milliseconds: 400),
  }) async {
    final completer = Completer<void>();
    Timer? timer;
    void onChange() {
      timer?.cancel();
      timer = Timer(quietWindow, () {
        if (!completer.isCompleted) completer.complete();
      });
    }
    changes.addListener(onChange);
    onChange();
    try {
      await completer.future;
    } finally {
      changes.removeListener(onChange);
      timer?.cancel();
    }
  }
}
/// Rebuilds every widget that reads fold state through the `context.isFolded`
/// / `isHalfOpened` / ... getters (see ContextExtension) whenever
/// [FoldableHelper.changes] fires — a posture change alone (e.g. halfOpened ->
/// unfolded) doesn't resize the window, so MediaQuery wouldn't rebuild them.
class FoldableScope extends InheritedNotifier<ValueNotifier<int>> {
  FoldableScope({super.key, required super.child})
      : super(notifier: FoldableHelper.changes);

  static void watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FoldableScope>();
}

/// Like [SafeArea], but for foldable reserved regions: pads [child] so it
/// stays clear of the camera and an active fold (see
/// [FoldableHelper.avoidInsets]).
///
/// Measures its own on-screen rect after each frame, so the padding settles
/// one frame after a fold/rotation. It re-measures on fold events and window
/// resizes, not on scrolling.
class FoldSafeArea extends StatefulWidget {
  const FoldSafeArea({
    super.key,
    required this.child,
    this.avoidCamera = true,
    this.avoidFold = true,
  });

  final Widget child;
  final bool avoidCamera;
  final bool avoidFold;

  @override
  State<FoldSafeArea> createState() => _FoldSafeAreaState();
}

class _FoldSafeAreaState extends State<FoldSafeArea> {
  EdgeInsets _insets = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    FoldableScope.watch(context);
    MediaQuery.sizeOf(context); // re-measure on window resize
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final insets = FoldableHelper.avoidInsets(
        box.localToGlobal(Offset.zero) & box.size,
        textDirection: textDirection,
        avoidCamera: widget.avoidCamera,
        avoidFold: widget.avoidFold,
      );
      if (insets != _insets) setState(() => _insets = insets);
    });

    return Padding(padding: _insets, child: widget.child);
  }
}

