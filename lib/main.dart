import 'package:flutter/material.dart';
import 'package:spatial_world/theme/app_theme.dart';
import 'package:spatial_world/widgets/spatial_board.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spatial World',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: SpatialBoard(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  Offset _delta = Offset.zero;
  Offset? _lastPointerPosition;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
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
    final screenSize = MediaQuery.of(context).size;
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Column(
            mainAxisAlignment: .center,
            children: [
              const Text('You have pushed the button this many times:'),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _incrementCounter,
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
