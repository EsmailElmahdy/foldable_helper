import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_device/foldable_device.dart';

/// Feeds one native event through the real channel, then checks the padding.
Future<void> sendEvent(Map<String, Object?> event) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
    const EventChannel('foldable_device'),
    MockStreamHandler.inline(onListen: (_, sink) => sink.success(event)),
  );
  await FoldableHelper.dispose();
  FoldableHelper.initialize();
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Inner display 951x669, vertical fold 455.5..495.5 (iPhone Duo simulator values).
  const fullWidthRow = Rect.fromLTWH(0, 100, 951, 60);

  test('active vertical fold keeps content on the start side', () async {
    await sendEvent({
      'state': 'halfOpened', 'isFoldableDevice': true, 'isVerticalHinge': true,
      'hingeLeft': 455.5, 'hingeTop': 0.0, 'hingeRight': 495.5, 'hingeBottom': 669.0,
      'isFoldActive': true,
    });
    expect(FoldableHelper.avoidInsets(fullWidthRow), const EdgeInsets.only(right: 951 - 455.5));
    expect(FoldableHelper.avoidInsets(fullWidthRow, textDirection: TextDirection.rtl),
        const EdgeInsets.only(left: 495.5));
    expect(FoldableHelper.avoidInsets(fullWidthRow, avoidFold: false), EdgeInsets.zero);
  });

  test('inactive fold adds no padding', () async {
    await sendEvent({
      'state': 'unfolded', 'isFoldableDevice': true, 'isVerticalHinge': true,
      'hingeLeft': 455.5, 'hingeTop': 0.0, 'hingeRight': 495.5, 'hingeBottom': 669.0,
      'isFoldActive': false,
    });
    expect(FoldableHelper.avoidInsets(fullWidthRow), EdgeInsets.zero);
  });

  test('active horizontal fold pads the bottom', () async {
    await sendEvent({
      'state': 'halfOpened', 'isFoldableDevice': true, 'isVerticalHinge': false,
      'hingeLeft': 0.0, 'hingeTop': 455.5, 'hingeRight': 669.0, 'hingeBottom': 495.5,
      'isFoldActive': true,
    });
    const column = Rect.fromLTWH(0, 400, 669, 200);
    expect(FoldableHelper.avoidInsets(column), const EdgeInsets.only(bottom: 600 - 455.5));
  });

  test('camera at the top: content starts after it, only where it overlaps', () async {
    await sendEvent({
      'state': 'folded', 'isFoldableDevice': true,
      'occlusions': [
        {'left': 850.0, 'top': 90.0, 'right': 900.0, 'bottom': 130.0, 'isActive': true},
      ],
    });
    // Camera (y 90..130) at the top of the row (y 100..160): content starts
    // after it -> top padding of 30, never left/right.
    expect(FoldableHelper.avoidInsets(fullWidthRow), const EdgeInsets.only(top: 130 - 100));
    expect(FoldableHelper.avoidInsets(const Rect.fromLTWH(0, 300, 951, 60)), EdgeInsets.zero);
    expect(FoldableHelper.avoidInsets(fullWidthRow, avoidCamera: false), EdgeInsets.zero);
  });

  test('rotated: camera in use at the bottom pads only the bottom, by its size', () async {
    await sendEvent({
      'state': 'folded', 'isFoldableDevice': true,
      'occlusions': [
        // Bottom-center camera on a 400x900 window.
        {'left': 180.0, 'top': 860.0, 'right': 220.0, 'bottom': 900.0, 'isActive': true},
      ],
    });
    const page = Rect.fromLTWH(0, 100, 400, 800);
    expect(FoldableHelper.avoidInsets(page), const EdgeInsets.only(bottom: 900 - 860));
  });

  test('folded: camera not in use adds no padding', () async {
    await sendEvent({
      'state': 'folded', 'isFoldableDevice': true,
      'occlusions': [
        {'left': 677.3, 'top': 21.0, 'right': 735.3, 'bottom': 58.0, 'isActive': false},
      ],
    });
    expect(FoldableHelper.avoidInsets(const Rect.fromLTWH(0, 0, 951, 100)), EdgeInsets.zero);
  });

  test('camera not in use is ignored in every posture; active status pill avoided', () async {
    await sendEvent({
      'state': 'halfOpened', 'isFoldableDevice': true,
      'occlusions': [
        {'left': 677.3, 'top': 21.0, 'right': 735.3, 'bottom': 58.0, 'isActive': false},
        {'left': 867.0, 'top': 0.0, 'right': 951.0, 'bottom': 124.0, 'isActive': true},
      ],
    });
    expect(FoldableHelper.avoidInsets(const Rect.fromLTWH(0, 30, 951, 20)),
        const EdgeInsets.only(top: 124 - 30));
  });
}
