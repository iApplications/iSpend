import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_settings_repository.dart';
import 'data/guide_catalog.dart';

const maxDisplayNameLength = 30;

/// Cleans a typed name: single spaces, no control characters, a sensible
/// length. Returns null for an empty name, so "no name" has one form.
String? normalizeDisplayName(String raw) {
  final text = raw
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return null;
  return text.length > maxDisplayNameLength
      ? text.substring(0, maxDisplayNameLength).trim()
      : text;
}

/// "Welcome back" without a name, "Welcome back, Sam" with one.
String greetingFor(String? name) =>
    name == null ? 'Welcome back' : 'Welcome back, $name';

/// The optional name shown in greetings. A local preference only: it is kept
/// in the encrypted app settings and never leaves the device.
final displayNameProvider = NotifierProvider<DisplayNameNotifier, String?>(
  DisplayNameNotifier.new,
);

class DisplayNameNotifier extends Notifier<String?> {
  static const settingKey = 'display_name';
  late AppSettingsRepository _repository;

  @override
  String? build() {
    _repository = ref.watch(appSettingsRepositoryProvider);
    Future<void>.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final stored = await _repository.read(settingKey);
    state = stored == null ? null : normalizeDisplayName(stored);
  }

  /// Saves [raw], or clears the name when it is empty. Returns the stored
  /// name.
  Future<String?> set(String raw) async {
    final name = normalizeDisplayName(raw);
    // The settings table stores text, so "no name" is an empty string.
    await _repository.write(settingKey, name ?? '');
    state = name;
    return name;
  }
}

class TutorialState {
  const TutorialState({
    this.loaded = false,
    this.welcomeVersion = 0,
    this.seen = const {},
  });

  /// False until the saved state has been read, so a guide never flashes for
  /// something the user already dismissed.
  final bool loaded;
  final int welcomeVersion;

  /// Guide id to the version the user last dismissed.
  final Map<String, int> seen;

  bool get welcomeDone => welcomeVersion >= welcomeGuideVersion;

  bool hasSeen(GuideTopic topic) => (seen[topic.id] ?? 0) >= topic.version;

  Map<String, Object?> toJson() => {'welcome': welcomeVersion, 'seen': seen};

  static TutorialState fromJson(Object? json) {
    if (json is! Map) return const TutorialState(loaded: true);
    final seen = <String, int>{};
    final raw = json['seen'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is int) {
          seen[entry.key as String] = entry.value as int;
        }
      }
    }
    final welcome = json['welcome'];
    return TutorialState(
      loaded: true,
      welcomeVersion: welcome is int ? welcome : 0,
      seen: seen,
    );
  }
}

/// Which one-time guides the user has dismissed. Kept in the encrypted app
/// settings (and so in a full backup); there is no analytics or tracking.
final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialState>(
  TutorialNotifier.new,
);

class TutorialNotifier extends Notifier<TutorialState> {
  static const settingKey = 'tutorial_state';
  late AppSettingsRepository _repository;

  @override
  TutorialState build() {
    _repository = ref.watch(appSettingsRepositoryProvider);
    Future<void>.microtask(refresh);
    return const TutorialState();
  }

  Future<void> refresh() async {
    final raw = await _repository.read(settingKey);
    if (raw == null) {
      state = const TutorialState(loaded: true);
      return;
    }
    try {
      state = TutorialState.fromJson(jsonDecode(raw));
    } catch (_) {
      state = const TutorialState(loaded: true);
    }
  }

  Future<void> _save(TutorialState next) async {
    state = next;
    try {
      await _repository.write(settingKey, jsonEncode(next.toJson()));
    } catch (_) {
      // A guide that cannot be remembered may show again; that is harmless.
    }
  }

  Future<void> markSeen(GuideTopic topic) {
    if (state.hasSeen(topic)) return Future.value();
    return _save(
      TutorialState(
        loaded: true,
        welcomeVersion: state.welcomeVersion,
        seen: {...state.seen, topic.id: topic.version},
      ),
    );
  }

  Future<void> completeWelcome() => _save(
    TutorialState(
      loaded: true,
      welcomeVersion: welcomeGuideVersion,
      seen: state.seen,
    ),
  );

  /// Makes every one-time feature guide show again. The welcome guide stays
  /// finished (it can be replayed from Help & Guide), and the display name and
  /// all expense data are left alone.
  Future<void> reset() =>
      _save(TutorialState(loaded: true, welcomeVersion: state.welcomeVersion));
}
