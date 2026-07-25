import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beatrice/ui/core/theme.dart';

/// Mirrors the root app's CodeBlock: a styled container with a header showing
/// the language label, a Copy button, and — for HTML/XML — a Code/Preview
/// toggle that renders the markup (Preview defaults on for HTML).
class CodeBlock extends StatefulWidget {
  final String code;
  final String language;

  const CodeBlock({super.key, required this.code, this.language = ''});

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;
  late bool _isHtml;
  late bool _showPreview;

  @override
  void initState() {
    super.initState();
    _isHtml = widget.language == 'html' || widget.language == 'xml';
    _showPreview = _isHtml;
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.codeBody,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.codeHeader,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      (widget.language.isNotEmpty ? widget.language : 'code')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.neutral400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_isHtml) ...[const SizedBox(width: 8), _toggle()],
                  ],
                ),
                GestureDetector(
                  onTap: _copy,
                  child: Row(
                    children: [
                      Icon(
                        _copied ? Icons.check : Icons.copy,
                        size: 13,
                        color: AppColors.neutral400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copied ? 'Copied!' : 'Copy',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.neutral400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isHtml && _showPreview)
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(child: HtmlWidget(widget.code)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                widget.code,
                style:
                    GoogleFonts.jetBrainsMonoTextTheme(
                      Theme.of(context).textTheme,
                    ).bodyMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.neutral300,
                      height: 1.5,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _toggleBtn('Code', !_showPreview),
          _toggleBtn('Preview', _showPreview),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _showPreview = label == 'Preview'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.neutral600 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : AppColors.neutral400,
          ),
        ),
      ),
    );
  }
}
