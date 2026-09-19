import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'android_home_widget.dart';
import 'android_app_shortcuts.dart';

import '../categories/category_providers.dart';
import '../payment_methods/payment_method_providers.dart';
import 'data/quick_entry_template.dart';
import 'data/quick_entry_template_repository.dart';

final quickEntryTemplateRepositoryProvider =
    Provider<QuickEntryTemplateRepository>(
      (_) => InMemoryQuickEntryTemplateRepository(),
    );

final quickEntryTemplatesProvider =
    NotifierProvider<QuickEntryTemplatesNotifier, List<QuickEntryTemplate>>(
      QuickEntryTemplatesNotifier.new,
    );

final quickEntryTemplateReferencesProvider =
    FutureProvider<QuickEntryTemplateReferences>((ref) async {
      final categoryIds = await ref
          .watch(categoryRepositoryProvider)
          .getIdsByName();
      final paymentMethodIds = await ref
          .watch(paymentMethodRepositoryProvider)
          .getIdsByName();
      return QuickEntryTemplateReferences(
        categoryNamesById: {
          for (final entry in categoryIds.entries) entry.value: entry.key,
        },
        paymentMethodNamesById: {
          for (final entry in paymentMethodIds.entries) entry.value: entry.key,
        },
      );
    });

class QuickEntryTemplateReferences {
  const QuickEntryTemplateReferences({
    required this.categoryNamesById,
    required this.paymentMethodNamesById,
  });

  final Map<String, String> categoryNamesById;
  final Map<String, String> paymentMethodNamesById;
}

class QuickEntryTemplatesNotifier extends Notifier<List<QuickEntryTemplate>> {
  late final QuickEntryTemplateRepository _repository;

  @override
  List<QuickEntryTemplate> build() {
    _repository = ref.watch(quickEntryTemplateRepositoryProvider);
    Future<void>.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    state = await _repository.getAll();
    await AndroidHomeWidget.refresh(state);
    await AndroidAppShortcuts.refresh(state);
  }

  Future<void> save(QuickEntryTemplate template) async {
    await _repository.save(template);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await refresh();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final reordered = List<QuickEntryTemplate>.of(state);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    state = [
      for (var index = 0; index < reordered.length; index++)
        reordered[index].copyWith(sortOrder: index),
    ];
    await _repository.reorder(state.map((item) => item.id).toList());
    await AndroidHomeWidget.refresh(state);
    await AndroidAppShortcuts.refresh(state);
  }

  Future<int> countByCategoryId(String id) => _repository.countByCategoryId(id);
  Future<int> countByPaymentMethodId(String id) =>
      _repository.countByPaymentMethodId(id);
}
