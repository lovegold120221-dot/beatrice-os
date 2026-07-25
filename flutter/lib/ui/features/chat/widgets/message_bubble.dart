import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:beatrice/data/models/message.dart';
import 'package:beatrice/ui/core/theme.dart';
import 'package:beatrice/ui/core/widgets/code_block.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;

  const MessageBubble({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: isUser ? _buildUserBubble() : _buildModelBubble(context),
      ),
    );
  }

  Widget _buildUserBubble() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.hover2f,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4), // notch removed top-right
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.image != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.image!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          Text(
            message.text,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelBubble(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Text(
            'E',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.black,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.image != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildImageWithOverlay(message.image!),
                ),
              if (message.text.isNotEmpty)
                MarkdownBody(
                  data: message.text,
                  builders: {'pre': _CodeBlockBuilder()},
                  styleSheet: _markdownStyle(context),
                  shrinkWrap: true,
                  selectable: true,
                ),
              if (_hasSources) _buildSources(),
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasSources {
    final chunks = message.groundingMetadata?['groundingChunks'];
    return chunks is List && chunks.isNotEmpty;
  }

  Widget _buildSources() {
    final chunks = message.groundingMetadata?['groundingChunks'] as List;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.search, size: 12, color: AppColors.neutral400),
                SizedBox(width: 6),
                Text(
                  'Sources',
                  style: TextStyle(fontSize: 12, color: AppColors.neutral400),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chunks.map<Widget>((c) {
              final web = c is Map ? c['web'] : null;
              final title = (web is Map ? web['title'] : null) ?? 'Source';
              return Container(
                constraints: const BoxConstraints(maxWidth: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.attach2a,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x0DFFFFFF)),
                ),
                child: Text(
                  title.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inlineCodeText,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithOverlay(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          if (message.isImageGen)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.download,
                  size: 16,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final base = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final body = base.bodyMedium?.copyWith(
      color: AppColors.neutral200,
      fontSize: 15,
      height: 1.6,
    );
    return MarkdownStyleSheet(
      p: body,
      h1: base.bodyLarge?.copyWith(
        color: AppColors.white,
        fontWeight: FontWeight.w600,
        fontSize: 24,
      ),
      h2: base.bodyLarge?.copyWith(
        color: AppColors.white,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      h3: base.bodyLarge?.copyWith(
        color: AppColors.white,
        fontWeight: FontWeight.w600,
        fontSize: 17,
      ),
      h4: base.bodyLarge?.copyWith(
        color: AppColors.white,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      strong: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.white,
      ),
      a: const TextStyle(
        color: AppColors.linkBlue,
        decoration: TextDecoration.underline,
      ),
      blockquote: const TextStyle(color: Color(0xFFA1A1AA)),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF3F3F46), width: 3)),
      ),
      code: GoogleFonts.jetBrainsMonoTextTheme(Theme.of(context).textTheme)
          .bodyMedium
          ?.copyWith(
            color: AppColors.inlineCodeText,
            fontSize: 13,
            backgroundColor: const Color(0x1AFFFFFF),
          ),
      // The custom <pre> builder draws its own container, so neutralize the
      // default codeblock wrapper.
      codeblockDecoration: const BoxDecoration(),
      listIndent: 20,
    );
  }
}

/// Renders fenced code blocks (`pre`) as the custom [CodeBlock] widget with a
/// copy button and an HTML Code/Preview toggle, matching the root app.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  String _language = '';

  @override
  bool isBlockElement() => true;

  @override
  void visitElementBefore(md.Element element) {
    _language = '';
    // The <pre> wraps a <code> child whose class carries the language.
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'code') {
        final cls = child.attributes['class'] ?? '';
        final m = RegExp(r'language-([\w-]+)').firstMatch(cls);
        if (m != null) _language = m.group(1)!;
        break;
      }
    }
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    final code = text.text.replaceFirst(RegExp(r'\n$'), '');
    if (code.isEmpty) return null;
    return CodeBlock(code: code, language: _language);
  }
}
