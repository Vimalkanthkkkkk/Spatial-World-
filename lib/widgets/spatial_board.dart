import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:spatial_world/widgets/split_layer.dart';

class SpatialBoard extends StatefulWidget {
  const SpatialBoard({super.key});

  @override
  State<SpatialBoard> createState() => _SpatialBoardState();
}

class _SpatialBoardState extends State<SpatialBoard> {
  final Controller controller = Controller();
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    _textController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _textController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () {
                      final text = _textController.text.trim();
                      if (text.isEmpty) return;
                      controller.addCard(const Offset(100, 100), text);
                      Navigator.pop(context);
                    },
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerMove: (event) => controller.panBy(event.delta),
      child: Scaffold(
        resizeToAvoidBottomInset: false, 
        body: RepaintBoundary(
          child: CustomPaint(
            size: ui.Size.infinite,
            painter: CardPainter(controller),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddDialog,
          tooltip: 'Add',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}