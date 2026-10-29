import 'dart:collection';

import 'package:flutter/widgets.dart';

// ignore: slash_for_doc_comments
/*
 Item (base fields)
  Unique stable id (never an index)
  Type (card, text, image, group, timeline)
  Position (top-left in world)
  Size
  Z-order (stable integer, unique ordering)
  Parent group id (optional)
  Style reference
  Content reference (text string, image asset key)
  Version or modified time
 */

typedef Content = ({String? text, Image? img});

typedef Style = ({Color color, Radius radius});

typedef Position = ({int x, int y});

typedef Size = ({int width, int height});

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

typedef Addresult = ({double originX, double originY, (int, int) index});

typedef ItemsMap = HashMap<(int, int), Item>;

class Controller {
  ItemsMap items = HashMap();
  late String heldId;
  Map<String, TextPainter> textCache = {};
  Map<String, Paint> paintObj = {};
  final SceneVersion scene = SceneVersion();
  CameraNotifier camera = CameraNotifier();
  List<Item> renderItems(Size screen, Offset delta) => camera
      .moveto(screen, delta)
      .map((index) => items[index])
      .whereType<Item>()
      .toList();

  Addresult addCard(Offset delta) {
    return camera.addItem(delta);
  }

  Item? removecard((int, int) index) {
    final removed = items.remove(index);
    return removed;
  }
  
}

class CameraNotifier with ChangeNotifier {
  final List<int> topLeft = [-100, -100];
  final int cellSize = 200;
  final int boundary = 200;

  Addresult addItem(Offset delta) {
    final originX = (topLeft[0] + delta.dx) + boundary;
    final originY = (topLeft[1] + delta.dy) + boundary;
    final column = (originX / cellSize).floor();
    final row = (originY / cellSize).floor();
    notifyListeners();
    return (originX: originX, originY: originY, index: (row, column));
  }

  List<(int, int)> moveto(Size screen, Offset delta) {
    final int screenWidth = screen.width + boundary;
    final int screenHeight = screen.height + boundary;
    final originX = topLeft[0] + delta.dx;
    final originY = topLeft[1] + delta.dy;
    final colStart = ((-boundary - originX) / cellSize).floor();
    final rowStart = ((-boundary - originY) / cellSize).floor();
    final colEnd = ((screenWidth - originX) / cellSize).floor();
    final rowEnd = ((screenHeight - originY) / cellSize).floor();
    List<(int, int)> visibleItemsIndex = [];
    for (var i = colStart; i < colEnd; i++) {
      for (var j = rowStart; j < rowEnd; j++) {
        visibleItemsIndex.add((j, i));
      }
    }
    notifyListeners();
    return visibleItemsIndex;
  }
}

class SceneVersion {
  final ValueNotifier<int> sceneVersion = ValueNotifier<int>(0);

  void incrementVersion() {
    sceneVersion.value++;
  }
}
