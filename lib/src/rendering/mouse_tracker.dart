import 'dart:io';
import '../keyboard/mouse_event.dart';
import '../framework/framework.dart';
import 'mouse_hit_test.dart';

// Debug logging
final _trackerLog = File('mouse_debug.log');
void _logTracker(String message) {
  try {
    final timestamp = DateTime.now().toIso8601String();
    _trackerLog.writeAsStringSync('[$timestamp] TRACKER: $message\n', mode: FileMode.append);
  } catch (_) {}
}

/// Signature for mouse enter/exit/hover callbacks.
typedef MouseEventCallback = void Function(MouseEvent event);

/// An annotation that attaches mouse event callbacks to a render object.
class MouseTrackerAnnotation {
  MouseTrackerAnnotation({
    this.onEnter,
    this.onExit,
    this.onHover,
    required this.renderObject,
  });

  /// Called when the mouse enters the annotated region.
  final MouseEventCallback? onEnter;

  /// Called when the mouse exits the annotated region.
  final MouseEventCallback? onExit;

  /// Called when the mouse moves within the annotated region.
  final MouseEventCallback? onHover;

  /// The render object this annotation is attached to.
  final RenderObject renderObject;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MouseTrackerAnnotation && other.renderObject == renderObject;
  }

  @override
  int get hashCode => renderObject.hashCode;
}

/// Tracks mouse annotations and dispatches enter/exit/hover events.
class MouseTracker {
  /// The set of annotations currently under the mouse cursor.
  final Set<MouseTrackerAnnotation> _hoveredAnnotations = {};

  /// The last known mouse position.
  Offset? _lastPosition;

  /// Update the hovered annotations based on hit test results and dispatch events.
  void updateAnnotations(
    MouseHitTestResult hitTestResult,
    MouseEvent event,
  ) {
    final position = Offset(event.x.toDouble(), event.y.toDouble());
    _lastPosition = position;

    _logTracker('updateAnnotations: pos=$position entries=${hitTestResult.mouseEntries.length}');

    // Collect all annotations from the hit test result
    final Set<MouseTrackerAnnotation> newAnnotations = {};
    for (final entry in hitTestResult.mouseEntries) {
      _logTracker('updateAnnotations: checking entry, target type=${entry.target.runtimeType}');
      if (entry.target is MouseTrackerAnnotationProvider) {
        final annotation =
            (entry.target as MouseTrackerAnnotationProvider).annotation;
        if (annotation != null) {
          _logTracker('updateAnnotations: found annotation');
          newAnnotations.add(annotation);
        } else {
          _logTracker('updateAnnotations: annotation is null');
        }
      } else {
        _logTracker('updateAnnotations: target is not MouseTrackerAnnotationProvider');
      }
    }

    _logTracker('updateAnnotations: found ${newAnnotations.length} annotations, previously had ${_hoveredAnnotations.length}');

    // Find annotations that were exited
    final exitedAnnotations = _hoveredAnnotations.difference(newAnnotations);
    for (final annotation in exitedAnnotations) {
      _logTracker('updateAnnotations: calling onExit');
      annotation.onExit?.call(event);
    }

    // Find annotations that were entered
    final enteredAnnotations = newAnnotations.difference(_hoveredAnnotations);
    for (final annotation in enteredAnnotations) {
      _logTracker('updateAnnotations: calling onEnter');
      annotation.onEnter?.call(event);
    }

    // Dispatch hover events to all currently hovered annotations
    for (final annotation in newAnnotations) {
      _logTracker('updateAnnotations: calling onHover');
      annotation.onHover?.call(event);
    }

    // Update the set of hovered annotations
    _hoveredAnnotations.clear();
    _hoveredAnnotations.addAll(newAnnotations);
  }

  /// Clear all hovered annotations (e.g., when mouse leaves the terminal).
  void clear(MouseEvent event) {
    for (final annotation in _hoveredAnnotations) {
      annotation.onExit?.call(event);
    }
    _hoveredAnnotations.clear();
    _lastPosition = null;
  }
}

/// Interface for render objects that provide mouse tracker annotations.
mixin MouseTrackerAnnotationProvider {
  MouseTrackerAnnotation? get annotation;
}
