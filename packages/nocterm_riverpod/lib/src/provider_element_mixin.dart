import 'package:nocterm/nocterm.dart';
import 'package:meta/meta.dart';

import 'framework.dart';

// Type alias for better readability
typedef _ProviderScopeElement = dynamic;

/// Mixin to add provider dependency cleanup to elements.
/// 
/// This mixin hooks into the element lifecycle to ensure proper cleanup
/// of provider subscriptions.
@internal
mixin ProviderElementMixin on Element {
  _ProviderScopeElement? _providerScopeElement;
  
  @override
  void mount(Element? parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    // Find and cache the provider scope element on mount
    _findProviderScope();
  }
  
  @override
  void activate() {
    super.activate();
    // Re-find provider scope after reactivation
    _findProviderScope();
  }
  
  @override
  void deactivate() {
    // Clean up provider dependencies before deactivating
    _cleanupProviderDependencies();
    super.deactivate();
  }
  
  @override
  void unmount() {
    // Final cleanup on unmount
    _cleanupProviderDependencies();
    super.unmount();
  }
  
  @override
  void performRebuild() {
    // Notify provider dependencies about rebuild
    _notifyProviderDependenciesOfRebuild();
    super.performRebuild();
  }
  
  void _findProviderScope() {
    try {
      // Try to find the provider scope element
      final element = this as BuildContext;
      _providerScopeElement = element.getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>();
    } catch (_) {
      // Provider scope not found, that's okay
      _providerScopeElement = null;
    }
  }
  
  void _cleanupProviderDependencies() {
    if (_providerScopeElement != null) {
      _providerScopeElement!.removeDependencies(this);
      _providerScopeElement = null;
    }
  }
  
  void _notifyProviderDependenciesOfRebuild() {
    if (_providerScopeElement != null) {
      final dependencies = _providerScopeElement!._dependents[this];
      dependencies?.didRebuildDependent();
    }
  }
}