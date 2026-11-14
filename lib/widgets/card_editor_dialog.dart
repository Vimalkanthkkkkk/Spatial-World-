import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

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

final ThemeData _darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFB0B5BA),
    surface: Color(0xFF262626),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Colors.white,
    selectionColor: Color(0x55FFFFFF),
  ),
);

class CardEditorDialog extends StatefulWidget {
  const CardEditorDialog({
    super.key,
    this.initialTitle = '',
    this.initialText,
    this.initialDeltaJson,
    this.initialColor,
    this.confirmLabel = 'Add',
    this.startReadOnly = false,
  });

  final String initialTitle;
  final String? initialText;
  final String? initialDeltaJson;
  final Color? initialColor;
  final String confirmLabel;
  final bool startReadOnly;

  @override
  State<CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends State<CardEditorDialog> {
  late final TextEditingController _title;
  late final QuillController _quill;
  late final ValueNotifier<Color> _color;
  late final ValueNotifier<bool> _readOnly;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _color = ValueNotifier(widget.initialColor ?? cardPalette.first);
    _readOnly = ValueNotifier(widget.startReadOnly);
    _quill = QuillController(
      document: _initialDocument(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quill.readOnly = widget.startReadOnly;
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && !_readOnly.value) _focus.requestFocus();
    });
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
    _color.dispose();
    _readOnly.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setReadOnly(bool value) {
    _readOnly.value = value;
    _quill.readOnly = value;
    if (value) {
      _focus.unfocus();
    } else {
      _focus.requestFocus();
    }
  }

  void _save() {
    final text = _quill.document.toPlainText().trim();
    final title = _title.text.trim();
    if (text.isEmpty && title.isEmpty) return;

    final CardEditorResult result = (
      title: title,
      text: text,
      deltaJson: jsonEncode(_quill.document.toDelta().toJson()),
      color: _color.value,
    );
    Navigator.pop(context, result);
  }

  Widget _styleButton(IconData icon, Attribute attribute, String tooltip) {
    return ListenableBuilder(
      listenable: _quill,
      builder: (context, _) {
        final current = _quill.getSelectionStyle().attributes[attribute.key];
        final active = current?.value == attribute.value;
        return IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: active ? Colors.white24 : Colors.transparent,
          ),
          icon: Icon(icon, size: 20),
          onPressed: () => _quill.formatSelection(
            active ? Attribute.clone(attribute, null) : attribute,
          ),
        );
      },
    );
  }

  Widget _colorRow() {
    return Row(
      children: [
        const Text('Color', style: TextStyle(color: Colors.white70)),
        const SizedBox(width: 12),
        Expanded(
          child: ValueListenableBuilder<Color>(
            valueListenable: _color,
            builder: (context, selected, _) => Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final c in cardPalette)
                  GestureDetector(
                    onTap: () => _color.value = c,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c == selected ? Colors.white : Colors.white24,
                          width: c == selected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        _styleButton(Icons.format_bold, Attribute.bold, 'Bold'),
        _styleButton(Icons.format_italic, Attribute.italic, 'Italic'),
        _styleButton(Icons.format_underline, Attribute.underline, 'Underline'),
        _styleButton(Icons.format_list_bulleted, Attribute.ul, 'Bullet list'),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height * 0.85;
    final editor = QuillEditor.basic(
      controller: _quill,
      focusNode: _focus,
      config: QuillEditorConfig(
        placeholder: 'Write something…',
        padding: EdgeInsets.zero,
      ),
    );

    return Theme(
      data: _darkTheme,
      child: Dialog(
        backgroundColor: const Color(0xFF262626),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: screenHeight > 560 ? 560 : screenHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _readOnly,
                          builder: (context, ro, _) => TextField(
                            controller: _title,
                            readOnly: ro,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              hintText: ro
                                  ? null
                                  : 'Title (optional, first line is used if empty)',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<bool>(
                        valueListenable: _readOnly,
                        builder: (context, ro, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Read-only',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: ro,
                                onChanged: _setReadOnly,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _readOnly,
                    builder: (context, ro, _) {
                      if (ro) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _colorRow(),
                          const SizedBox(height: 8),
                          _toolbar(),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ValueListenableBuilder<Color>(
                      valueListenable: _color,
                      child: editor,
                      builder: (context, color, child) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: _readOnly,
                    builder: (context, ro, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: ro
                          ? [
                              FilledButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ]
                          : [
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