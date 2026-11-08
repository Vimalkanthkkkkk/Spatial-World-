import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef Content = ({String? text, Image? img});
typedef Style = ({Color color, Radius radius});
typedef Position = ({double x, double y});
typedef Size = ({double width, double height});

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

class Controller {
  static const int cellSize = 200;
  final Map<(int, int), List<Item>> grid = HashMap();
  final ValueNotifier<Offset> camera = ValueNotifier(Offset.zero);
  final ValueNotifier<int> scene = ValueNotifier(0);
  late final Listenable repaint = Listenable.merge([camera, scene]);
  final Paint fill = Paint()..style = PaintingStyle.fill;
  final Map<String, ({int version, TextPainter painter})> _text = {};

  double _maxExtent = 0;
  int _nextId = 0;
  String heldItem = '';
  (int, int, int, int)? _lastRange;
  int _lastScene = -1;
  List<Item> _visible = const [];

  void panBy(Offset delta) => camera.value += delta;

  (int, int) _cellOf(double x, double y) =>
      ((y / cellSize).floor(), (x / cellSize).floor());

  Item addCard(Offset screenPoint, String text) {
    final world = screenPoint - camera.value;
    final id = _nextId++;
    final Item item = (
      id: 'item_$id',
      type: 'CARD',
      position: (x: world.dx, y: world.dy),
      size: (width: 100, height: 100),
      zOrder: id,
      parentId: 0,
      style: (
        color: const Color.fromARGB(247, 23, 23, 223),
        radius: const Radius.circular(10),
      ),
      content: (text: text, img: null),
      version: 1,
    );
    grid.putIfAbsent(_cellOf(world.dx, world.dy), () => []).add(item);
    if (item.size.width > _maxExtent) _maxExtent = item.size.width;
    if (item.size.height > _maxExtent) _maxExtent = item.size.height;
    scene.value++;
    return item;
  }

  void removeCard(Item item) {
    final key = _cellOf(item.position.x, item.position.y);
    final cell = grid[key];
    if (cell == null) return;
    cell.removeWhere((i) => i.id == item.id);
    if (cell.isEmpty) grid.remove(key);
    _text.remove(item.id)?.painter.dispose();
    scene.value++;
  }

  List<Item> visibleItems(ui.Size screen) {
    final pan = camera.value;
    final left = -pan.dx - _maxExtent;
    final top = -pan.dy - _maxExtent;
    final right = -pan.dx + screen.width;
    final bottom = -pan.dy + screen.height;
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

  TextPainter? textFor(Item item) {
    final text = item.content.text;
    if (text == null || text.isEmpty) return null;

    final cached = _text[item.id];
    if (cached != null && cached.version == item.version) {
      return cached.painter;
    }
    cached?.painter.dispose();
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 4,
      ellipsis: '…',
    )..layout(maxWidth: item.size.width - 16);
    _text[item.id] = (version: item.version, painter: painter);
    return painter;
  }

  void dispose() {
    for (final entry in _text.values) {
      entry.painter.dispose();
    }
    _text.clear();
    camera.dispose();
    scene.dispose();
  }
}

class CardPainter extends CustomPainter {
  CardPainter(this.controller) : super(repaint: controller.repaint);
  final Controller controller;

  @override
  void paint(Canvas canvas, ui.Size size) {
    final pan = controller.camera.value;
    print(pan);
    final viewport = Rect.fromLTWH(-pan.dx, -pan.dy, size.width, size.height);
    final items = controller.visibleItems(size);
    final fill = controller.fill;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.translate(pan.dx, pan.dy);

    for (final item in items) {
      print(item);
      final rect = Rect.fromLTWH(
        item.position.x,
        item.position.y,
        item.size.width,
        item.size.height,
      );
      if (!viewport.overlaps(rect)) continue;
      fill.color = item.style.color;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, item.style.radius), fill);
      controller
          .textFor(item)
          ?.paint(canvas, rect.topLeft + const Offset(8, 8));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(CardPainter oldDelegate) =>
      oldDelegate.controller != controller;
}

class DynamicPainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, ui.Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    throw UnimplementedError();
  }
}
