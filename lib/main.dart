import 'package:flutter/material.dart';
import './screens/Mapview.dart';
import './carpbackground/CarpLocation.dart' as CL;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String logStr = '';

  int i = 0;

  @override
  void initState() {
    super.initState();
    CL.start();
  }

  @override
  void dispose() => super.dispose();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MapView(),
    );
  }
}
