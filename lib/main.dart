import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import './screens/map_view.dart';
import './carpBackground/carp_location.dart' as CL;
import 'backgroundTasks/background_fetch.dart';



void main() {
  runApp(const MyApp());

  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}


class MyApp extends StatefulWidget {
  const MyApp({Key key}) : super(key: key);

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
    initPlatformState();
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
