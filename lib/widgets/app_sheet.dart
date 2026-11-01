import 'package:flutter/material.dart';

/// One presentation style for every bottom sheet in the app.
///
/// Using a single entry point keeps the barrier colour, corner radius, drag
/// handle and safe-area behaviour identical, so sheets no longer animate in
/// with a transparent background or fight the route for the drag gesture.
class AppSheet {
  const AppSheet._();

  static const Duration animationDuration = Duration(milliseconds: 260);
  static const double _radius = 28;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool enableDrag = true,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      enableDrag: enableDrag,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      clipBehavior: Clip.antiAlias,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: animationDuration,
              reverseDuration: animationDuration,
            ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_radius)),
      ),
      builder: builder,
    );
  }
}
