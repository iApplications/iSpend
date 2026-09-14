import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/database/app_settings_repository.dart';
import '../../core/widgets/app_toast.dart';

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

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;
  bool _promptedForCurrentLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setState(() {
        _unlocked = false;
        _promptedForCurrentLock = false;
      });
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
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
      if (mounted) setState(() => _authenticating = false);
    }
  }

  void _showAuthenticationError(String message) {
    AppToast.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appLockEnabledProvider);
    if (enabled == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!enabled) return widget.child;
    if (_unlocked) return widget.child;
    if (!_promptedForCurrentLock && !_authenticating) {
      _promptedForCurrentLock = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
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
                  onPressed: _authenticating ? null : _unlock,
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
}
