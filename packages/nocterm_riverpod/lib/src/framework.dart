import 'dart:async';

import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';
import 'package:riverpod/riverpod.dart';

/// A component that stores the state of providers.
///
/// This component is necessary to use any provider-related functionality.
/// It should be placed at the root of the component tree:
///
/// ```dart
/// runApp(
///   ProviderScope(
///     child: MyApp(),
///   ),
/// );
/// ```
class ProviderScope extends StatefulComponent {
  const ProviderScope({
    super.key,
    this.parent,
    this.overrides = const [],
    this.observers,
    required this.child,
  });

  /// The parent container if this is a nested scope
  final ProviderContainer? parent;

  /// Overrides for providers in this scope
  final List<Override> overrides;

  /// Observers for provider state changes
  final List<ProviderObserver>? observers;

  /// The child component
  final Component child;

  @override
  State<ProviderScope> createState() => _ProviderScopeState();

  /// Returns the [ProviderContainer] of the closest [ProviderScope] ancestor.
  static ProviderContainer containerOf(
    BuildContext context, {
    bool listen = true,
  }) {
    UncontrolledProviderScope? scope;

    if (listen) {
      scope = context.dependOnInheritedComponentOfExactType<UncontrolledProviderScope>();
    } else {
      print('What');
      scope = context.findAncestorComponentOfExactType<UncontrolledProviderScope>();
    }

    if (scope == null) {
      throw StateError(
        'ProviderScope not found. Make sure to wrap your app with a ProviderScope.',
      );
    }

    return scope.container;
  }
}

class _ProviderScopeState extends State<ProviderScope> {
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();

    _container = ProviderContainer(
      parent: component.parent,
      overrides: component.overrides,
      observers: component.observers,
    );
  }

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return UncontrolledProviderScope(
      container: _container,
      child: component.child,
    );
  }
}

/// An [InheritedComponent] that exposes a [ProviderContainer] to its descendants.
///
/// This is the internal implementation used by [ProviderScope].
@internal
class UncontrolledProviderScope extends InheritedComponent {
  const UncontrolledProviderScope({
    super.key,
    required this.container,
    required super.child,
  });

  /// The container that holds all provider state
  final ProviderContainer container;

  @override
  bool updateShouldNotify(UncontrolledProviderScope oldComponent) {
    return container != oldComponent.container;
  }
}
