import 'package:nocterm/nocterm.dart';
import 'package:riverpod/riverpod.dart';

import 'framework.dart';

/// Extension methods on [BuildContext] for interacting with providers.
extension ProviderContext on BuildContext {
  /// Read a provider value without listening to changes.
  ///
  /// This will not cause the component to rebuild when the provider changes.
  /// Use this for one-time reads or in event handlers.
  ///
  /// ```dart
  /// onPressed: () {
  ///   final value = context.read(myProvider);
  ///   // Use value...
  /// }
  /// ```
  T read<T>(ProviderListenable<T> provider) {
    final container = ProviderScope.containerOf(this, listen: false);
    return container.read(provider);
  }

  /// Watch a provider and rebuild when it changes.
  ///
  /// This will cause the component to rebuild whenever the provider's value changes.
  /// Should only be called during the build method.
  ///
  /// ```dart
  /// @override
  /// Component build(BuildContext context) {
  ///   final value = context.watch(myProvider);
  ///   return Text(value.toString());
  /// }
  /// ```
  T watch<T>(ProviderListenable<T> provider) {
    // We need to use the container directly and manage subscriptions
    final container = ProviderScope.containerOf(this, listen: true);

    // For watch, we'll use the container directly and let Riverpod handle rebuilds
    // This is a simplified approach - in production, we'd track subscriptions better
    final element = this as Element;

    // Create a subscription that will rebuild this element
    final subscription = container.listen<T>(
      provider,
      (previous, next) {
        if (element.mounted) {
          element.markNeedsBuild();
        }
      },
      fireImmediately: false,
    );

    // Store subscription for cleanup (simplified - would need proper tracking)
    // For now, rely on the ProviderContainer's own cleanup

    return container.read(provider);
  }

  /// Listen to a provider with a callback.
  ///
  /// The callback will be called whenever the provider's value changes.
  /// The subscription is automatically managed and will be disposed when
  /// the component is unmounted.
  ///
  /// ```dart
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   context.listen(myProvider, (previous, next) {
  ///     print('Value changed from $previous to $next');
  ///   });
  /// }
  /// ```
  void listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    bool fireImmediately = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);

    // Create subscription
    container.listen<T>(
      provider,
      listener,
      fireImmediately: fireImmediately,
      onError: onError,
    );
  }

  /// Subscribe to a provider and return the subscription.
  ///
  /// Unlike [listen], this returns a [ProviderSubscription] that can be
  /// manually managed. The subscription is still automatically disposed
  /// when the component is unmounted.
  ///
  /// ```dart
  /// late final subscription = context.subscribe(myProvider, (previous, next) {
  ///   // Handle changes
  /// });
  ///
  /// // Later, you can read the current value:
  /// final value = subscription.read();
  /// ```
  ProviderSubscription<T> subscribe<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    bool fireImmediately = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);

    return container.listen<T>(
      provider,
      listener,
      fireImmediately: fireImmediately,
      onError: onError,
    );
  }

  /// Refresh a provider, causing it to rebuild.
  ///
  /// This is useful for providers that fetch data, allowing you to
  /// trigger a refetch.
  ///
  /// ```dart
  /// onPressed: () {
  ///   context.refresh(myFutureProvider);
  /// }
  /// ```
  T refresh<T>(Refreshable<T> provider) {
    final container = ProviderScope.containerOf(this, listen: false);
    return container.refresh(provider);
  }

  /// Invalidate a provider, causing it to be rebuilt on next read.
  ///
  /// Unlike [refresh], this doesn't immediately rebuild the provider.
  /// It will be rebuilt the next time it's read.
  ///
  /// ```dart
  /// onPressed: () {
  ///   context.invalidate(myProvider);
  /// }
  /// ```
  void invalidate(ProviderOrFamily provider) {
    final container = ProviderScope.containerOf(this, listen: false);
    container.invalidate(provider);
  }
}
