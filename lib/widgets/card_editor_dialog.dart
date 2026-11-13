import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

typedef CardEditorResult = ({
  String title,
  String text,
  String deltaJson,
  Color color,
});

const List<Color> cardPalette = [
  Color(0xFF2B2B2B),
  Color(0xFF3B3F46),
  Color(0xFF1E3A5F),
  Color(0xFF14532D),
  Color(0xFF5B2333),
  Color(0xFF4A3B1B),
  Color(0xFF3B2A5C),
  Color(0xFF0F4C5C),
];

class CardEditorDialog extends StatefulWidget {
  const CardEditorDialog({
    super.key,
    this.initialTitle = '',
    this.initialText,
    this.initialDeltaJson,
    this.initialColor,
    this.confirmLabel = 'Add',
  });

  final String initialTitle;
  final String? initialText;
  final String? initialDeltaJson;
  final Color? initialColor;
  final String confirmLabel;

  @override
  State<CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends State<CardEditorDialog> {
  late final TextEditingController _title;
  late final QuillController _quill;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _color = widget.initialColor ?? cardPalette.first;
    _quill = QuillController(
      document: _initialDocument(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  Document _initialDocument() {
    final json = widget.initialDeltaJson;
    if (json != null) return Document.fromJson(jsonDecode(json) as List);
    final doc = Document();
    final text = widget.initialText;
    if (text != null && text.isNotEmpty) doc.insert(0, text);
    return doc;
  }

  @override
  void dispose() {
    _title.dispose();
    _quill.dispose();
    super.dispose();
  }

  void _save() {
    final text =
        _quill.document.toPlainText().replaceAll('\uFFFC', '').trim();
    final title = _title.text.trim();
    if (text.isEmpty && title.isEmpty) return;

    final CardEditorResult result = (
      title: title,
      text: text,
      deltaJson: jsonEncode(_quill.document.toDelta().toJson()),
      color: _color,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB0B5BA),
          surface: Color(0xFF262626),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Color(0x55FFFFFF),
        ),
      ),
      child: Dialog(
        backgroundColor: const Color(0xFF262626),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: screenHeight > 620 ? 620 : screenHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _title,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Title (optional, first line is used if empty)',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Color',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final c in cardPalette)
                              GestureDetector(
                                onTap: () => setState(() => _color = c),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: c == _color
                                          ? Colors.white
                                          : Colors.white24,
                                      width: c == _color ? 2.5 : 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  QuillSimpleToolbar(
                    controller: _quill,
                    config: QuillSimpleToolbarConfig(
                      multiRowsDisplay: false,
                      color: const Color(0xFF303030),
                      embedButtons: FlutterQuillEmbeds.toolbarButtons(
                        videoButtonOptions: null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: QuillEditor.basic(
                        controller: _quill,
                        config: QuillEditorConfig(
                          autoFocus: true,
                          placeholder: 'Write something…',
                          padding: EdgeInsets.zero,
                          embedBuilders: FlutterQuillEmbeds.editorBuilders()
                              .where((b) => b.key != BlockEmbed.videoType)
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _save,
                        child: Text(widget.confirmLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}