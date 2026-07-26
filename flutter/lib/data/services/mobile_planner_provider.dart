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

abstract final class MobilePlannerProviders {
  static const ollamaLocal = 'ollama-local';
  static const ollamaCloud = 'ollama-cloud';
  static const gemini = 'gemini';
  static const groq = 'groq';

  static const options = <MobilePlannerProvider>[
    MobilePlannerProvider(
      id: ollamaLocal,
      label: 'Eburon-local',
      description: 'Local planner runs on this device; works offline.',
      isIntegrated: true,
      isOnline: false,
    ),
    MobilePlannerProvider(
      id: ollamaCloud,
      label: 'Eburon-cloud',
      description: 'Cloud planner sends task context online.',
      isIntegrated: true,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: gemini,
      label: 'Eburon',
      description: 'Online planner with your API key.',
      isIntegrated: true,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: groq,
      label: 'Eburon-OS',
      description: 'Online planner with your API key.',
      isIntegrated: true,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'openai',
      label: 'Saturn',
      description: 'Planner adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'claude',
      label: 'Venus',
      description: 'Planner adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'deepseek',
      label: 'Mercury',
      description: 'Planner adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'qwen',
      label: 'Uranus',
      description: 'Planner adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'opencode-zen-free',
      label: 'Callisto',
      description: 'Planner adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'opencode-go',
      label: 'Europa',
      description: 'Planner adapter is not configured yet.',
      isIntegrated: false,
      isOnline: true,
    ),
    MobilePlannerProvider(
      id: 'custom',
      label: 'Pluto',
      description: 'Custom endpoint adapter is not configured yet.',
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
