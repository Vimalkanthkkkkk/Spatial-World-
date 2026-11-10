import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:spatial_world/widgets/split_layer.dart';

class SpatialBoard extends StatefulWidget {
  const SpatialBoard({super.key});

  @override
  State<SpatialBoard> createState() => _SpatialBoardState();
}

class _SpatialBoardState extends State<SpatialBoard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Controller controller;

  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
      vsync: this,
    );
    controller = Controller(_animationController);
    controller.scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack, 
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    final kind = event.kind;
    final canPan =
        kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
    controller.pointerDown(event.pointer, event.localPosition, canPan: canPan);
  }

  void _onPointerMove(PointerMoveEvent event) {
    controller.pointerMove(event.pointer, event.localPosition, event.delta);
  }

  void _onPointerEnd(PointerEvent event) {
    controller.pointerEnd(event.pointer);
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
          constraints: BoxConstraints(minHeight: 200, maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _textController,
                  maxLines: 10,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    helperMaxLines: 4,
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
        body: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: ui.Size.infinite,
                painter: CardPainter(controller),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(painter: DynamicPainter(controller)),
            ),
          ],
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
