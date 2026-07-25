class Message {
  final String role;
  final String text;
  final String? image;
  final String? audio;
  final bool isImageGen;
  final Map<String, dynamic>? groundingMetadata;
  final String? originalPrompt;

  const Message({
    required this.role,
    required this.text,
    this.image,
    this.audio,
    this.isImageGen = false,
    this.groundingMetadata,
    this.originalPrompt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    role: json['role'] as String? ?? 'model',
    text: json['text'] as String? ?? '',
    image: json['image_url'] as String?,
    isImageGen: json['is_image_gen'] as bool? ?? false,
    originalPrompt: json['original_prompt'] as String?,
  );

  Message copyWith({String? text, Map<String, dynamic>? groundingMetadata}) =>
      Message(
        role: role,
        text: text ?? this.text,
        image: image,
        audio: audio,
        isImageGen: isImageGen,
        groundingMetadata: groundingMetadata ?? this.groundingMetadata,
        originalPrompt: originalPrompt,
      );
}
