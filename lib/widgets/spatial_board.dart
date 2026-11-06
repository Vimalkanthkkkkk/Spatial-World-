import 'dart:ui' as ui;
import 'package:flutter/gestures.dart'; 
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
  int? _panPointer;

  @override
  void dispose() {
    controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    final kind = event.kind;
    final canPan = kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
    if (!canPan) return;
    _panPointer ??= event.pointer;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _panPointer) return;
    controller.panBy(event.delta);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer == _panPointer) _panPointer = null;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    controller.panBy(event.panDelta);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      controller.panBy(-event.scrollDelta);
    }
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
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      onPointerSignal: _onPointerSignal,
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