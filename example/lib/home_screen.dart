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
      appBar: AppBar(
          title: Center(
            child: const Text('Foldable Device Example', style: TextStyle(fontSize: 28, color: Colors.white)),
          ),
        backgroundColor: Colors.blueAccent,
      ),

      // Pads the whole body away from the camera while it's in use (top
      // padding when the camera is at the top, bottom padding after rotating
      // it to the bottom). avoidFold: false lets the panes span the fold.
      body: FoldSafeArea(
        avoidCamera: true,
        avoidFold: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
              InkWell(
                onTap: () => debugPrint('Pressed'),
                child: Padding(
                  padding: const EdgeInsetsGeometry.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.green,
                    ),
                    width: double.infinity,
                    child: Center(child: const Text('Tap Me', style: TextStyle(fontSize: 48)),),
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

            // Two panes only when open like a book (vertical fold);
            // open like a laptop or folded -> one yellow pane.
            // TwoPane / Container need a bounded height inside a Column.
            Expanded(
              child: isOpen && FoldableHelper.isVerticalHinge
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
      ),
    );
  }
}
