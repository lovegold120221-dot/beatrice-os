class MobilePlannerProvider {
  final String id;
  final String label;
  final String description;
  final bool isIntegrated;
  final bool isOnline;

  const MobilePlannerProvider({
    required this.id,
    required this.label,
    required this.description,
    required this.isIntegrated,
    required this.isOnline,
  });
}

/// Provider choices shown in Beatrice setup.
///
/// Only providers with a production planner adapter are marked integrated.
/// Keeping the capability state in this registry prevents the UI from implying
/// that a visible provider can already execute MobileUseAgent tasks.
abstract final class MobilePlannerProviders {
  static const ollamaLocal = 'ollama-local';
  static const ollamaCloud = 'ollama-cloud';

  static const options = <MobilePlannerProvider>[
    MobilePlannerProvider(
      id: ollamaLocal,
      label: 'Ollama · Local',
      description: 'Termux Ollama on this phone; works offline.',
      isIntegrated: true,
      isOnline: false,
    ),
    MobilePlannerProvider(
      id: ollamaCloud,
      label: 'Ollama · Cloud',
      description: 'Ollama Cloud; sends task context online.',
      isIntegrated: true,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'gemini',
      label: 'Gemini',
      description: 'Planner adapter and key setup are not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'groq',
      label: 'Groq',
      description: 'Planner adapter and key setup are not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'openai',
      label: 'OpenAI',
      description: 'Planner adapter and key setup are not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'claude',
      label: 'Claude',
      description: 'Anthropic planner adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'deepseek',
      label: 'DeepSeek',
      description: 'Planner adapter and key setup are not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'qwen',
      label: 'Qwen',
      description:
          'Direct Qwen provider setup is not configured; Qwen via Ollama works.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'opencode-zen-free',
      label: 'OpenCode Zen · Free models',
      description: 'OpenCode planner execution adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'opencode-go',
      label: 'OpenCode Go',
      description: 'OpenCode planner execution adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'custom',
      label: 'Custom model',
      description: 'A custom endpoint adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
  ];

  static MobilePlannerProvider byId(String id) {
    return options.firstWhere(
      (option) => option.id == id,
      orElse: () => options.first,
    );
  }
}
