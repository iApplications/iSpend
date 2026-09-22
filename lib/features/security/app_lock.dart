import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/database/app_settings_repository.dart';
import '../../core/widgets/app_toast.dart';
import '../quick_entry/android_app_shortcuts.dart';

abstract interface class AppLockAuthenticator {
  Future<bool> authenticate();
}

class LocalAppLockAuthenticator implements AppLockAuthenticator {
  const LocalAppLockAuthenticator();

  @override
  Future<bool> authenticate() async {
    final authentication = LocalAuthentication();
    if (!await authentication.isDeviceSupported()) return false;
    return authentication.authenticate(
      localizedReason: 'Unlock iSpend to view your expense data.',
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );
  }
}

final appLockAuthenticatorProvider = Provider<AppLockAuthenticator>(
  (_) => const LocalAppLockAuthenticator(),
);

final appLockEnabledProvider = NotifierProvider<AppLockEnabledNotifier, bool?>(
  AppLockEnabledNotifier.new,
);

class AppLockEnabledNotifier extends Notifier<bool?> {
  static const _settingKey = 'app_lock_enabled';
  late final AppSettingsRepository _repository;

  @override
  bool? build() {
    _repository = ref.watch(appSettingsRepositoryProvider);
    Future<void>.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    state = await _repository.read(_settingKey) == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _repository.write(_settingKey, enabled.toString());
  }
}

final quickLoggingWithoutUnlockProvider =
    NotifierProvider<QuickLoggingWithoutUnlockNotifier, bool?>(
      QuickLoggingWithoutUnlockNotifier.new,
    );

class QuickLoggingWithoutUnlockNotifier extends Notifier<bool?> {
  static const _settingKey = 'quick_logging_without_unlock';
  late final AppSettingsRepository _repository;

  @override
  bool? build() {
    _repository = ref.watch(appSettingsRepositoryProvider);
    Future<void>.microtask(refresh);
    return null;
  }

  Future<void> refresh() async =>
      state = await _repository.read(_settingKey) == 'true';

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _repository.write(_settingKey, enabled.toString());
  }
}

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({
    required this.child,
    this.externalChildBuilder,
    super.key,
  });
  final Widget child;
  final Widget Function(Uri? uri, VoidCallback onComplete, int requestId)?
  externalChildBuilder;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;
  bool _promptedForCurrentLock = false;
  bool _authenticationLifecycleTransition = false;
  bool _externalSourcesReady = false;
  Uri? _externalUri;
  Uri? _lastAcceptedExternalUri;
  DateTime? _lastAcceptedExternalAt;
  int _externalRequestId = 0;
  Timer? _unlockDelay;
  bool _unlockScheduled = false;
  bool _returningToFullApp = false;
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.externalChildBuilder == null) {
      _externalSourcesReady = true;
      return;
    }
    _widgetClicks = HomeWidget.widgetClicked.listen(_acceptExternalUri);
    unawaited(_prepareExternalSources());
  }

  Future<void> _prepareExternalSources() async {
    final initialUriFuture = HomeWidget.initiallyLaunchedFromHomeWidget();
    final shortcutsFuture = AndroidAppShortcuts.initialize((action) async {
      final templateId = AndroidAppShortcuts.templateIdFromAction(action);
      _acceptExternalUri(
        Uri(
          scheme: 'ispend',
          host: 'quick-entry',
          queryParameters: {if (templateId != null) 'template_id': templateId},
        ),
      );
    });

    Uri? initialUri;
    try {
      initialUri = await initialUriFuture;
    } catch (_) {
      // A platform without HomeWidget support should still be able to open
      // the normal app after the short external-entry startup window.
    }
    try {
      await shortcutsFuture;
    } catch (_) {
      // Shortcut support is optional; the normal app lock must still work.
    }
    _acceptExternalUri(initialUri);
    if (mounted) setState(() => _externalSourcesReady = true);
  }

  void _acceptExternalUri(Uri? uri) {
    if (!mounted || uri?.host != 'quick-entry') return;
    _unlockDelay?.cancel();
    _unlockDelay = null;
    _unlockScheduled = false;
    _returningToFullApp = false;
    final now = DateTime.now();
    if (uri == _lastAcceptedExternalUri &&
        _lastAcceptedExternalAt != null &&
        now.difference(_lastAcceptedExternalAt!) <
            const Duration(milliseconds: 500)) {
      return;
    }
    _lastAcceptedExternalUri = uri;
    _lastAcceptedExternalAt = now;
    setState(() {
      _externalUri = uri;
      _externalRequestId++;
    });
  }

  @override
  void dispose() {
    _unlockDelay?.cancel();
    _widgetClicks?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // local_auth can resume the Flutter activity just after its Future has
      // completed. Clear the guard only after that transition has finished.
      if (!_authenticating) _authenticationLifecycleTransition = false;
      // The app was locked while it was in the background. Rebuild only now
      // so the authentication prompt appears after the user selects iSpend
      // from Android's Recents screen, not while they are browsing Recents.
      if (mounted) setState(() {});
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_authenticating ||
          _authenticationLifecycleTransition ||
          (_externalUri != null && _unlocked)) {
        return;
      }
      setState(() {
        _unlocked = false;
        _promptedForCurrentLock = false;
      });
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !_isForeground) return;
    _authenticationLifecycleTransition = true;
    setState(() {
      _authenticating = true;
    });
    try {
      final unlocked = await ref
          .read(appLockAuthenticatorProvider)
          .authenticate();
      if (!mounted) return;
      setState(() {
        _unlocked = unlocked;
      });
      if (!unlocked) {
        _showAuthenticationError('Authentication was not completed.');
      }
    } catch (_) {
      if (mounted) {
        _showAuthenticationError(
          'Authentication is unavailable on this device.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          _authenticationLifecycleTransition = false;
        }
      }
    }
  }

  void _showAuthenticationError(String message) {
    AppToast.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appLockEnabledProvider);
    final bypass = ref.watch(quickLoggingWithoutUnlockProvider);
    if (enabled == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.externalChildBuilder != null && !_externalSourcesReady) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (widget.externalChildBuilder != null && enabled && bypass == null) {
      // Do not start the normal app-lock flow until the persisted quick-entry
      // preference has loaded. A cold shortcut launch can otherwise begin
      // authentication before we know that the shortcut is allowed to bypass
      // the lock.
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_externalUri != null && widget.externalChildBuilder != null) {
      final opensFullApp = _externalUri!.queryParameters['more'] == 'true';
      final bypassAllowed = bypass == true && !opensFullApp;
      if (!enabled || _unlocked || bypassAllowed) {
        return widget.externalChildBuilder!(
          _externalUri,
          _completeExternalEntry,
          _externalRequestId,
        );
      }
    }
    if (!enabled) return widget.child;
    if (_unlocked) return widget.child;
    if (_isForeground && !_promptedForCurrentLock && !_authenticating) {
      if (widget.externalChildBuilder != null &&
          bypass == true &&
          !_returningToFullApp) {
        _scheduleUnlockAfterExternalLaunchWindow();
      } else {
        _promptedForCurrentLock = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
      }
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'iSpend is locked',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Use your device authentication to continue.'),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _authenticating || !_isForeground ? null : _unlock,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: Text(_authenticating ? 'Authenticating...' : 'Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _completeExternalEntry() {
    if (!mounted) return;
    setState(() {
      _externalUri = null;
      // Saving from an unlocked quick-entry surface should hand the user back
      // to the normal app, which remains protected by device authentication.
      _returningToFullApp = true;
      _promptedForCurrentLock = false;
    });
  }

  void _scheduleUnlockAfterExternalLaunchWindow() {
    if (_unlockScheduled) return;
    _unlockScheduled = true;
    _unlockDelay = Timer(const Duration(milliseconds: 750), () {
      _unlockScheduled = false;
      _unlockDelay = null;
      if (!mounted ||
          !_isForeground ||
          _externalUri != null ||
          _authenticating ||
          _unlocked) {
        return;
      }
      _promptedForCurrentLock = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isForeground && _externalUri == null) _unlock();
      });
    });
  }

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    // Flutter can report no lifecycle state during initial widget setup. That
    // is still a valid foreground launch; only inactive/paused states must
    // defer the authentication prompt.
    return state == null || state == AppLifecycleState.resumed;
  }
}
