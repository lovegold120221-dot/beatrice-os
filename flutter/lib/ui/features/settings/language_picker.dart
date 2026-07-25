import 'package:flutter/material.dart';
import 'package:beatrice/data/services/language_preferences.dart';
import 'package:beatrice/ui/core/theme.dart';

class LanguagePickerField extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onSelected;

  const LanguagePickerField({
    super.key,
    required this.selectedLanguage,
    required this.onSelected,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface0a,
      builder: (_) => _LanguagePickerSheet(selectedLanguage: selectedLanguage),
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: 'Select language',
          filled: true,
          fillColor: AppColors.chip2121,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          suffixIcon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.neutral400,
          ),
        ),
        child: Text(
          LanguagePreferences.normalize(selectedLanguage),
          style: const TextStyle(color: AppColors.white, fontSize: 14),
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  final String selectedLanguage;

  const _LanguagePickerSheet({required this.selectedLanguage});

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final languages = query.isEmpty
        ? LanguagePreferences.supportedLanguages
        : LanguagePreferences.supportedLanguages
              .where((language) => language.toLowerCase().contains(query))
              .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.neutral600,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Language',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: 'Search languages',
                hintStyle: const TextStyle(color: AppColors.neutral400),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.neutral400,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.neutral400,
                        ),
                      ),
                filled: true,
                fillColor: AppColors.chip2121,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
          ),
          Expanded(
            child: languages.isEmpty
                ? const Center(
                    child: Text(
                      'No languages found',
                      style: TextStyle(color: AppColors.neutral400),
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: languages.length,
                    itemBuilder: (context, index) {
                      final language = languages[index];
                      final selected = language == widget.selectedLanguage;
                      return ListTile(
                        title: Text(
                          language,
                          style: const TextStyle(color: AppColors.white),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check, color: AppColors.emerald)
                            : null,
                        onTap: () => Navigator.pop(context, language),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
