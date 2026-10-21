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
