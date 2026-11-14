import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Where UIKit places a bar of [measuredExtent] on the top edge of the window
/// (iOS 27.1+, see `SystemBarRegion` in AppDelegate.swift), measured for
/// [viewSize].
@immutable
class TopBarRegion {
  const TopBarRegion({
    required this.top,
    required this.left,
    required this.right,
    required this.viewSize,
  });

  final double top;
  final double left;
  final double right;
  final Size viewSize;

  /// Height of the bar the region was measured for.
  static const double measuredExtent = 48;

  @override
  bool operator ==(Object other) =>
      other is TopBarRegion &&
      other.top == top &&
      other.left == left &&
      other.right == right &&
      other.viewSize == viewSize;

  @override
  int get hashCode => Object.hash(top, left, right, viewSize);
}

/// Provides the system's top bar region to the widgets below it and keeps it
/// current as the window rotates, folds or unfolds.
class SystemBarRegion extends InheritedNotifier<ValueNotifier<TopBarRegion?>> {
  SystemBarRegion({super.key, required super.child})
      : super(notifier: _region);

  static const MethodChannel _channel =
      MethodChannel('com.meteor.kikoeruflutter/layout_regions');
  static final ValueNotifier<TopBarRegion?> _region = ValueNotifier(null);
  static _MetricsObserver? _observer;

  /// Starts measuring. Call after the binding is initialised.
  static void initialize() {
    if (!Platform.isIOS || _observer != null) return;
    _observer = _MetricsObserver();
    WidgetsBinding.instance.addObserver(_observer!);
    _refresh();
  }

  static Future<void> _refresh() async {
    try {
      final values =
          await _channel.invokeMapMethod<String, double>(
        'topBarRegion',
        TopBarRegion.measuredExtent,
      );
      _region.value = values == null
          ? null
          : TopBarRegion(
              top: values['top']!,
              left: values['left']!,
              right: values['right']!,
              viewSize: Size(values['width']!, values['height']!),
            );
    } on MissingPluginException {
      _region.value = null;
    } on PlatformException catch (e) {
      debugPrint('Top bar region unavailable: ${e.message}');
      _region.value = null;
    }
  }

  /// The top bar region for the window [context] belongs to, or null when the
  /// system gives none or it was measured before the window changed size.
  static TopBarRegion? topBarOf(BuildContext context) {
    final region = context
        .dependOnInheritedWidgetOfExactType<SystemBarRegion>()
        ?.notifier
        ?.value;
    if (region == null) return null;
    final view = View.of(context);
    final windowSize = view.physicalSize / view.devicePixelRatio;
    return region.viewSize == windowSize ? region : null;
  }
}

class _MetricsObserver with WidgetsBindingObserver {
  @override
  void didChangeMetrics() => SystemBarRegion._refresh();
}
