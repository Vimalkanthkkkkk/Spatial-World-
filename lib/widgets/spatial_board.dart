import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:spatial_world/widgets/split_layer.dart';
import 'package:spatial_world/widgets/card_editor_dialog.dart';

class SpatialBoard extends StatefulWidget {
  const SpatialBoard({super.key});
  @override
  State<SpatialBoard> createState() => _SpatialBoardState();
}

class _SpatialBoardState extends State<SpatialBoard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late final Ticker _autoScrollTicker;
  late Controller controller;
  double _lastScale = 1.0;

  Future<void> addCard() async {
    final result = await showDialog<CardEditorResult>(
      context: context,
      builder: (_) => const CardEditorDialog(),
    );
    if (result == null || !mounted) return;
    controller.addCard(
      Offset(controller.screenWidth / 2, controller.screenHeight / 2),
      title: result.title,
      text: result.text,
      deltaJson: result.deltaJson,
      color: result.color,
    );
  }

  Future<void> editCard(Item item) async {
    final result = await showDialog<CardEditorResult>(
      context: context,
      builder: (_) => CardEditorDialog(
        initialTitle: item.content.title ?? '',
        initialText: item.content.text,
        initialDeltaJson: controller.deltas[item.id],
        initialColor: item.style.color,
        confirmLabel: 'Save',
      ),
    );
    if (result == null || !mounted) return;
    controller.updateCard(
      item,
      title: result.title,
      text: result.text,
      deltaJson: result.deltaJson,
      color: result.color,
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
      vsync: this,
    );
    controller = Controller(_animationController);
    controller.onTapCard = editCard;
    _autoScrollTicker = createTicker((elapsed) {
      controller.autoScrollTick(elapsed);
    });
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
    _autoScrollTicker.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    final kind = event.kind;
    final canPan =
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
    controller.pointerDown(event.pointer, event.localPosition, canPan: canPan);
    if (controller.activePointer == event.pointer &&
        !_autoScrollTicker.isActive) {
      controller.resetAutoScroll();
      _autoScrollTicker.start();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    controller.pointerMove(event.pointer, event.localPosition, event.delta);
  }

  void _onPointerEnd(PointerEvent event) {
    controller.pointerEnd(event.pointer, isUp: event is PointerUpEvent);
    if (controller.activePointer == null && _autoScrollTicker.isActive) {
      _autoScrollTicker.stop();
    }
  }

  void _onPanZoomStart(PointerPanZoomStartEvent e) => _lastScale = 1.0;

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e) {
    controller.panBy(e.panDelta);
    final factor = e.scale / _lastScale;
    _lastScale = e.scale;
    controller.zoomAt(factor, e.localPosition);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScaleEvent) {
      controller.zoomAt(event.scale, event.localPosition);
    }
    if (event is PointerScrollEvent) {
      controller.panBy(-event.scrollDelta);
    }
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
      onPointerPanZoomStart: _onPanZoomStart,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            controller.screenWidth = constraints.maxWidth;
            controller.screenHeight = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(painter: CardPainter(controller) ),
                ),
                RepaintBoundary(
                  child: CustomPaint(painter: DynamicPainter(controller)),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: addCard,
          tooltip: 'Add',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
