import 'dart:async';
import 'dart:ui' as ui;
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

typedef Content = ({String? title, String? text, Image? img});
typedef Style = ({Color color, Radius radius});
typedef Position = ({double x, double y});
typedef Size = ({double width, double height});

enum TouchMode { idle, pending, armed, panning }

typedef Item = ({
  String id,
  String type,
  Position position,
  Size size,
  int zOrder,
  int parentId,
  Style style,
  Content content,
  int version,
});

void paintCardText(Controller c, Canvas canvas, Item item, Rect rect) {
  final t = c.textFor(item);
  if (t == null) return;
  const pad = Controller.cardPadding;
  t.title.paint(canvas, rect.topLeft + const Offset(pad, pad));
  t.body?.paint(
    canvas,
    rect.topLeft + Offset(pad, pad + t.title.height + 6),
  );
}

class Controller {
  Controller(this.animationController);

  AnimationController animationController;
  static const int cellSize = 200;
  final Map<(int, int), List<Item>> grid = HashMap();
  final ValueNotifier<Offset> camera = ValueNotifier(Offset.zero);
  final ValueNotifier<int> scene = ValueNotifier(0);
  final ValueNotifier<double> scale = ValueNotifier(1);
  late final Listenable repaint = Listenable.merge([camera, scene]);
  final Paint fill = Paint()..style = PaintingStyle.fill;
  double screenWidth = 0;
  double screenHeight = 0;

  double _maxExtent = 0;
  int _nextId = 0;
  static const Duration holdDuration = Duration(milliseconds: 300);
  static const double threshold = 10;
  TouchMode mode = TouchMode.idle;
  int? activePointer;
  bool _canPan = false;
  bool _disposed = false;
  Item? candidate;
  Offset downPosition = Offset.zero;
  Item? heldItem;
  final ValueNotifier<Offset> dragOffset = ValueNotifier(Offset.zero);
  late Animation<double> scaleAnimation;
  late final Listenable dynamicrepaint = Listenable.merge([
    camera,
    scene,
    dragOffset,
    animationController,
  ]);
  Timer? holdTimer;

  (int, int, int, int)? _lastRange;
  int _lastScene = -1;
  List<Item> _visible = const [];
  Duration lastElapsed = Duration.zero;
  static const double edgeMargin = 20;
  static const double maxScrollSpeed = 600;
  static const double speed = 0.7;

  static const double cardWidth = 240;
  static const double cardHeight = 160;
  static const double cardPadding = 12;

  final Map<String, String> deltas = {};
  void Function(Item item)? onTapCard;
  final Map<String, ({int version, TextPainter title, TextPainter? body})> _text = {};



  void panBy(Offset delta) => camera.value += delta * speed;
  void resetAutoScroll() => lastElapsed = Duration.zero;

  static const double minZoom = 0.1, maxZoom = 4.0;

  void zoomAt(double factor, Offset focal) {
    final z = scale.value;
    final newZ = (z * factor).clamp(minZoom, maxZoom);
    final ratio = newZ / z;
    if (ratio == 1) return;
    camera.value = focal - (focal - camera.value) * ratio;
    scale.value = newZ;
  }

  void autoScrollTick(Duration elapsed) {
    final zoomScale = scale.value;
    final held = heldItem;
    final dt = (elapsed - lastElapsed).inMicroseconds / 1000000.0;
    lastElapsed = elapsed;
    if (mode != TouchMode.armed || held == null || dt <= 0) return;
    final pan = camera.value;
    final drag = dragOffset.value;
    final left = (held.position.x + drag.dx) * zoomScale + pan.dx;
    final top = (held.position.y + drag.dy) * zoomScale + pan.dy;
    final right = left + held.size.width * zoomScale;
    final bottom = top + held.size.height * zoomScale;
    final vx = _edgeVelocity(left, right, screenWidth);
    final vy = _edgeVelocity(top, bottom, screenHeight);
    if (vx == 0 && vy == 0) return;
    final step = Offset(vx, vy) * (dt > 0.05 ? 0.05 : dt);
    camera.value = pan - step;
    dragOffset.value = drag + step / zoomScale;
  }

  double _edgeVelocity(double start, double end, double extent) {
    if (end > extent - edgeMargin) {
      final depth = ((end - (extent - edgeMargin)) / edgeMargin).clamp(
        0.0,
        1.0,
      );
      return depth * maxScrollSpeed;
    }
    if (start < edgeMargin) {
      final depth = ((edgeMargin - start) / edgeMargin).clamp(0.0, 1.0);
      return -depth * maxScrollSpeed;
    }
    return 0;
  }

  Item? findHeldItem(Offset local) {
    final z = scale.value;
    final world = (local - camera.value) / z;
    Item? best;
    for (final item in _visible) {
      final rect = Rect.fromLTWH(
        item.position.x,
        item.position.y,
        item.size.width,
        item.size.height,
      );
      if (rect.contains(world) && (best == null || item.zOrder > best.zOrder)) {
        best = item;
      }
    }
    return best;
  }

  (int, int) _cellOf(double x, double y) =>
      ((y / cellSize).floor(), (x / cellSize).floor());

  Item addCard(Offset screenPoint, {
    required String title,
    required String text,
    required String deltaJson,
    required Color color,
  }) {
    final z = scale.value;
    final world = (screenPoint - camera.value) / z - const Offset(cardWidth / 2, cardHeight / 2);
    final id = _nextId++;
    final Item item = (
      id: 'item_$id',
      type: 'CARD',
      position: (x: world.dx, y: world.dy),
      size: (width: cardWidth, height: cardHeight),
      zOrder: id,
      parentId: 0,
      style: (color: color, radius: const Radius.circular(14)),
      content: (title: title, text: text, img: null),
      version: 1,
    );
    deltas[item.id] = deltaJson;
    grid.putIfAbsent(_cellOf(world.dx, world.dy), () => []).add(item);
    if (item.size.width > _maxExtent) _maxExtent = item.size.width;
    if (item.size.height > _maxExtent) _maxExtent = item.size.height;
    scene.value++;
    return item;
  }

  void updateCard(Item item, {
    required String title,
    required String text,
    required String deltaJson,
    required Color color,
  }) {
    final cell = grid[_cellOf(item.position.x, item.position.y)];
    if (cell == null) return;
    final i = cell.indexWhere((e) => e.id == item.id);
    if (i < 0) return;
    final old = cell[i];
    cell[i] = (
      id: old.id,
      type: old.type,
      position: old.position,
      size: old.size,
      zOrder: old.zOrder,
      parentId: old.parentId,
      style: (color: color, radius: old.style.radius),
      content: (title: title, text: text, img: old.content.img),
      version: old.version + 1, 
    );
    deltas[old.id] = deltaJson;
    scene.value++;
  }

  void removeCard(Item item) {
    final key = _cellOf(item.position.x, item.position.y);
    final cell = grid[key];
    if (cell == null) return;
    cell.removeWhere((i) => i.id == item.id);
    if (cell.isEmpty) grid.remove(key);
    final cached = _text.remove(item.id);
    cached?.title.dispose();
    cached?.body?.dispose();
    deltas.remove(item.id);
    scene.value++;
  }

  List<Item> visibleItems(ui.Size screen) {
    final zoom = scale.value;
    final pan = camera.value;
    final worldLeft = -pan.dx / zoom;
    final worldTop = -pan.dy / zoom;
    final worldRight = (-pan.dx + screen.width) / zoom;
    final worldBottom = (-pan.dy + screen.height) / zoom;
    final left = worldLeft - _maxExtent;
    final top = worldTop - _maxExtent;
    final right = worldRight;
    final bottom = worldBottom;
    final c0 = (left / cellSize).floor();
    final c1 = (right / cellSize).floor();
    final r0 = (top / cellSize).floor();
    final r1 = (bottom / cellSize).floor();
    final range = (c0, c1, r0, r1);
    if (range == _lastRange && _lastScene == scene.value) return _visible;
    final out = <Item>[];
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final cell = grid[(r, c)];
        if (cell != null) out.addAll(cell);
      }
    }
    out.sort((a, b) => a.zOrder.compareTo(b.zOrder));
    _lastRange = range;
    _lastScene = scene.value;
    return _visible = out;
  }

  ({String title, String body}) split(Content c) {
    final full = (c.text ?? '').trim();
    final explicit = (c.title ?? '').trim();
    if (explicit.isNotEmpty) return (title: explicit, body: full);
    final nl = full.indexOf('\n');
    if (nl < 0) return (title: full, body: '');
    return (
      title: full.substring(0, nl).trim(),
      body: full.substring(nl + 1).trim(),
    );
  }


  ({TextPainter title, TextPainter? body})? textFor(Item item) {
    final cached = _text[item.id];
    if (cached != null && cached.version == item.version) {
      return (title: cached.title, body: cached.body);
    }
    cached?.title.dispose();
    cached?.body?.dispose();
    final parts = split(item.content);
    if (parts.title.isEmpty && parts.body.isEmpty) {
      _text.remove(item.id);
      return null;
    }
    final maxWidth = item.size.width - cardPadding * 2;
    final title = TextPainter(
      text: TextSpan(
        text: parts.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    TextPainter? body;
    if (parts.body.isNotEmpty) {
      const fontSize = 13.0;
      const lineHeight = 1.3;
      final available = item.size.height - cardPadding * 2 - title.height - 6;
      final lines = (available / (fontSize * lineHeight)).floor();
      if (lines >= 1) {
        body = TextPainter(
          text: TextSpan(
            text: parts.body,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: fontSize,
              height: lineHeight,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
          maxLines: lines,
          ellipsis: '…',
        )..layout(maxWidth: maxWidth);
      }
    }
    _text[item.id] = (version: item.version, title: title, body: body);
    return (title: title, body: body);
  }

  void pointerDown(int pointer, Offset local, {required bool canPan}) {
    if (activePointer != null || heldItem != null) return;
    activePointer = pointer;
    _canPan = canPan;
    downPosition = local;
    final hit = findHeldItem(local);
    if (hit != null) {
      candidate = hit;
      mode = TouchMode.pending;
      holdTimer?.cancel();
      holdTimer = Timer(holdDuration, _arm);
    } else {
      mode = canPan ? TouchMode.panning : TouchMode.idle;
    }
  }

  void _arm() {
    final c = candidate;
    if (_disposed || mode != TouchMode.pending || c == null) return;
    heldItem = c;
    candidate = null;
    dragOffset.value = Offset.zero;
    mode = TouchMode.armed;
    scene.value++;
    animationController.forward(from: 0);
  }

  void pointerMove(int pointer, Offset local, Offset delta) {
    if (pointer != activePointer) {
      return;
    }
    switch (mode) {
      case TouchMode.pending:
        if ((local - downPosition).distance > threshold) {
          holdTimer?.cancel();
          candidate = null;
          mode = _canPan ? TouchMode.panning : TouchMode.idle;
          if (mode == TouchMode.panning) panBy(local - downPosition);
        }
      case TouchMode.armed:
        dragOffset.value += delta / scale.value;
      case TouchMode.panning:
        break;
      case TouchMode.idle:
        break;
    }
  }

  void pointerEnd(int pointer, {bool isUp = false}) {
    if (pointer != activePointer) return;
    final tapped = (isUp && mode == TouchMode.pending) ? candidate : null;
    holdTimer?.cancel();
    holdTimer = null;
    candidate = null;
    final wasArmed = mode == TouchMode.armed;
    mode = TouchMode.idle;
    activePointer = null;
    if (wasArmed) {
      animationController.reverse().whenComplete(_commit);
    }
    if (tapped != null) onTapCard?.call(tapped);
  }

  void _commit() {
    final item = heldItem;
    if (_disposed || item == null) return;
    final d = dragOffset.value;
    final oldKey = _cellOf(item.position.x, item.position.y);
    final oldCell = grid[oldKey];
    oldCell?.removeWhere((i) => i.id == item.id);
    if (oldCell != null && oldCell.isEmpty) grid.remove(oldKey);
    final x = item.position.x + d.dx;
    final y = item.position.y + d.dy;
    final Item moved = (
      id: item.id,
      type: item.type,
      position: (x: x, y: y),
      size: item.size,
      zOrder: item.zOrder,
      parentId: item.parentId,
      style: item.style,
      content: item.content,
      version: item.version,
    );
    grid.putIfAbsent(_cellOf(x, y), () => []).add(moved);
    heldItem = null;
    scene.value++;
    dragOffset.value = Offset.zero;
  }

  void dispose() {
    _disposed = true;
    holdTimer?.cancel();
    for (final entry in _text.values) {
      entry.title.dispose();
      entry.body?.dispose();
    }
    _text.clear();
    dragOffset.dispose();
    camera.dispose();
    scene.dispose();
  }

}

class CardPainter extends CustomPainter {
  CardPainter(this.controller) : super(repaint: controller.repaint);
  final Controller controller;

  @override
  void paint(Canvas canvas, ui.Size size) {
    final scale = controller.scale.value;
    final pan = controller.camera.value;
    final viewport = Rect.fromLTWH(
      -pan.dx / scale,
      -pan.dy / scale,
      size.width / scale,
      size.height / scale,
    );
    final items = controller.visibleItems(size);
    final heldId = controller.heldItem?.id;
    final fill = controller.fill;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(scale);
    for (final item in items) {
      if (item.id == heldId) continue;
      final rect = Rect.fromLTWH(
        item.position.x,
        item.position.y,
        item.size.width,
        item.size.height,
      );
      if (!viewport.overlaps(rect)) continue;
      fill.color = item.style.color;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, item.style.radius), fill);
      paintCardText(controller, canvas, item, rect);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CardPainter oldDelegate) =>
      oldDelegate.controller != controller;
}

class DynamicPainter extends CustomPainter {
  DynamicPainter(this.controller) : super(repaint: controller.dynamicrepaint);
  final Controller controller;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final heldItem = controller.heldItem;
    if (heldItem == null) return;
    final pan = controller.camera.value;
    final drag = controller.dragOffset.value;
    final scale = controller.scaleAnimation.value;
    final zoomScale = controller.scale.value;
    final rect = Rect.fromLTWH(
      heldItem.position.x + drag.dx,
      heldItem.position.y + drag.dy,
      heldItem.size.width,
      heldItem.size.height,
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoomScale);
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(scale);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    controller.fill.color = heldItem.style.color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, heldItem.style.radius),
      controller.fill,
    );
    paintCardText(controller, canvas, heldItem, rect);
    canvas.restore();
  }

  @override
  bool shouldRepaint(DynamicPainter oldDelegate) {
    return oldDelegate.controller != controller;
  }
}
