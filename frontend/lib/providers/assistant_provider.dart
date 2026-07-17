import 'package:dummy_apps/providers/products_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AssistantNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() => {};

  /// Sends one prompt to `POST /api/assistant` (Gemini filter + DB query).
  Future<Map<String, dynamic>> searchProducts(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      throw Exception('Prompt cannot be empty');
    }

    final data = await ref
        .read(productProvider.notifier)
        .searchWithPrompt(trimmed);
    state = data;
    return data;
  }
}

final assistantProvider =
    NotifierProvider<AssistantNotifier, Map<String, dynamic>>(
      AssistantNotifier.new,
    );
