import 'package:flutter/material.dart';
import 'package:spatial_world/widgets/split_layer.dart';

import 'dart:ui' as ui;

class SpatialBoard extends StatefulWidget {
  const SpatialBoard({super.key});

  @override
  State<StatefulWidget> createState() {
    return _SpatialBoardState();
  }
}

class _SpatialBoardState extends State<SpatialBoard> {
  Offset _delta = Offset.zero;
  Offset? _lastPointerPosition;
  Controller controller = Controller();

  final TextEditingController _textController = TextEditingController();

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
                      controller.addCard(_delta, text);
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

  void _handlePointerDown(PointerDownEvent event) {
    _lastPointerPosition = event.localPosition;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_lastPointerPosition == null) return;
    _delta += event.localPosition - _lastPointerPosition!;
    _lastPointerPosition = event.localPosition;
    debugPrint('Delta: $_delta');
  }

  void _handlePointerUp(PointerUpEvent event) {
    _lastPointerPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    ui.Size screenSize = MediaQuery.of(context).size;
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: controller.camera,
          builder: (BuildContext context, Widget? child) {
            List<Item> cards = controller.renderItems(screenSize, _delta);
            return CustomPaint(
              size: screenSize,
              painter: CardPainter(
                items: cards,
                paintCache: controller.paintObj,
              ),
            );
          },
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
