import 'dart:async';
import 'dart:convert';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carp_background_location/carp_background_location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'database/funcs.dart';
import 'package:intl/intl.dart';


const EVENTS_KEY = "fetch_events";


final f = funcs.instance;
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  var taskId = task.taskId;
  var timeout = task.timeout;
  if (timeout) {
    print("[BackgroundFetch] Headless task timed-out: $taskId");
    BackgroundFetch.finish(taskId);
    return;
  }

  print("[BackgroundFetch] Headless event received: $taskId");

  var timestamp = DateTime.now();

  var prefs = await SharedPreferences.getInstance();

  // Read fetch_events from SharedPreferences
  var events = <String>[];
  var json = prefs.getString(EVENTS_KEY);
  if (json != null) {
    events = jsonDecode(json).cast<String>();
  }
  // Add new event.
  events.insert(0, "$taskId@$timestamp [Headless]");
  // Persist fetch events in SharedPreferences
  prefs.setString(EVENTS_KEY, jsonEncode(events));

  if (taskId == 'flutter_background_fetch') {
    main();
    BackgroundFetch.scheduleTask(TaskConfig(
        taskId: "yami",
        delay: 5000,
        periodic: false,
        forceAlarmManager: false,
        stopOnTerminate: false,
        enableHeadless: true
    ));
  }
  BackgroundFetch.finish(taskId);
}

void main() {
  runApp(MyApp());


}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();

}

enum LocationStatus { UNKNOWN, INITIALIZED, RUNNING, STOPPED }

String dtoToString(LocationDto dto) =>
    'Location ${dto.latitude}, ${dto.longitude} at ${DateTime.fromMillisecondsSinceEpoch(dto.time ~/ 1)}';

Widget dtoWidget(LocationDto dto) {
  if (dto == null) {
    print('gg');
    return Text("No location yet");
  } else {
    print('${DateTime.fromMillisecondsSinceEpoch(dto.time ~/ 1)}');
    return Column(
      children: <Widget>[
        Text(
          '${dto.latitude}, ${dto.longitude}',
        ),
        const Text(
          '@',
        ),
        Text('${DateTime.fromMillisecondsSinceEpoch(dto.time ~/ 1)}')
      ],
    );
  }
}

class _MyAppState extends State<MyApp> {
  bool _enabled = true;
  int _bstatus = 0;
  List<String> _events = [];

  String logStr = '';
  LocationDto lastLocation;
  DateTime lastTimeLocation;
  Stream<LocationDto> locationStream;
  StreamSubscription<LocationDto> locationSubscription;
  LocationStatus _status = LocationStatus.UNKNOWN;
  int i = 0;
  final Set<Polyline> polyline = {};
  List<LatLng> points = [];
  List<LatLng> dpoints = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();

    f.query();
    LocationManager().interval = 1;
    LocationManager().distanceFilter = 0;
    LocationManager().notificationTitle = 'CARP Location Example';
    LocationManager().notificationMsg = 'CARP is tracking your location';
    locationStream = LocationManager().locationStream;
    start();
    _status = LocationStatus.INITIALIZED;
  }

  Future<void> initPlatformState() async {
    // Load persisted fetch events from SharedPreferences
    var prefs = await SharedPreferences.getInstance();
    var json = prefs.getString(EVENTS_KEY);
    if (json != null) {
      setState(() {
        _events = jsonDecode(json).cast<String>();
      });
    }

    // Configure BackgroundFetch.
    try {
      var status = await BackgroundFetch.configure(BackgroundFetchConfig(
          minimumFetchInterval: 5,
          forceAlarmManager: false,
          stopOnTerminate: false,
          startOnBoot: true,
          enableHeadless: true,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
          requiredNetworkType: NetworkType.NONE
      ), _onBackgroundFetch, _onBackgroundFetchTimeout);
      print('[BackgroundFetch] configure success: $status');

      // Schedule a "one-shot" custom-task in 10000ms.
      // These are fairly reliable on Android (particularly with forceAlarmManager) but not iOS,
      // where device must be powered (and delay will be throttled by the OS).
      BackgroundFetch.scheduleTask(TaskConfig(
          taskId: "yami",
          delay: 100,
          periodic: false,
          forceAlarmManager: true,
          stopOnTerminate: false,
          enableHeadless: true
      ));
    } on Exception catch(e) {
      print("[BackgroundFetch] configure ERROR: $e");
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  void _onBackgroundFetch(String taskId) async {
    var prefs = await SharedPreferences.getInstance();
    var timestamp = DateTime.now();
    // This is the fetch-event callback.
    print("[BackgroundFetch] Event received: $taskId");
    setState(() {
      _events.insert(0, "$taskId@${timestamp.toString()}");
    });
    // Persist fetch events in SharedPreferences
    prefs.setString(EVENTS_KEY, jsonEncode(_events));

    if (taskId == "yami") {
      start();
      main();
      // Schedule a one-shot task when fetch event received (for testing).
      /*
      BackgroundFetch.scheduleTask(TaskConfig(
          taskId: "yami",
          delay: 5000,
          periodic: false,
          forceAlarmManager: true,
          stopOnTerminate: false,
          enableHeadless: true,
          requiresNetworkConnectivity: true,
          requiresCharging: true
      ));
       */
    }
    // IMPORTANT:  You must signal completion of your fetch task or the OS can punish your app
    // for taking too long in the background.
    BackgroundFetch.finish(taskId);
  }

  /// This event fires shortly before your task is about to timeout.  You must finish any outstanding work and call BackgroundFetch.finish(taskId).
  void _onBackgroundFetchTimeout(String taskId) {
    print("[BackgroundFetch] TIMEOUT: $taskId");
    BackgroundFetch.finish(taskId);
  }




  void getCurrentLocation() async =>
      onData(await LocationManager().getCurrentLocation());

  LocationDto onData(LocationDto dto) {
    LatLng p = new LatLng(dto.latitude, dto.longitude);
    if (p != null) {
      points.add(p);
    }

    i++;
    print("inside");
    f.insert(dto.latitude, dto.longitude,'${DateTime.fromMillisecondsSinceEpoch(dto.time ~/ 1)}');
    if (i == 1) {
      _controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(dto.latitude, dto.longitude),
        zoom: 18.0,
      )));
    }
    setState(() {
      lastLocation = dto;
      lastTimeLocation = DateTime.now();
    });
    return dto;
  }

  /// Is "location always" permission granted?
  Future<bool> isLocationAlwaysGranted() async =>
      await Permission.locationAlways.isGranted;

  /// Tries to ask for "location always" permissions from the user.
  /// Returns `true` if successful, `false` othervise.
  Future<bool> askForLocationAlwaysPermission() async {
    bool granted = await Permission.locationAlways.isGranted;

    if (!granted) {
      granted =
          await Permission.locationAlways.request() == PermissionStatus.granted;
    }

    return granted;
  }

  /// Start listening to location events.
  void start() async {
    // ask for location permissions, if not already granted
    print('startedddddddddddd');
    if (!await isLocationAlwaysGranted())
      await askForLocationAlwaysPermission();

    locationSubscription?.cancel();
    locationSubscription = locationStream?.listen(onData);
    await LocationManager().start();
    setState(() {
      _status = LocationStatus.RUNNING;
    });
  }

  void stop() {
    locationSubscription?.cancel();
    LocationManager().stop();
    setState(() {
      _status = LocationStatus.STOPPED;
    });
  }

  Widget stopButton() => SizedBox(
        width: double.maxFinite,
        child: ElevatedButton(
          child: const Text('STOP'),
          onPressed: stop,
        ),
      );

  Widget startButton() => SizedBox(
        width: double.maxFinite,
        child: ElevatedButton(
          child: const Text('START'),
          onPressed: start,
        ),
      );

  Widget status() => Text("Status: ${_status.toString().split('.').last}");

  Widget lastLoc() => Text(
      lastLocation != null
          ? dtoToString(lastLocation)
          : 'Unknown last location',
      textAlign: TextAlign.center);

  Widget currentLocationButton() => SizedBox(
        width: double.maxFinite,
        child: ElevatedButton(
          child: const Text('CURRENT LOCATION'),
          onPressed: getCurrentLocation,
        ),
      );

  @override
  void dispose() => super.dispose();
  GoogleMapController _controller;

  static const LatLng _center = const LatLng(33.5255495, 36.2772437);

  void _onMapCreated(GoogleMapController controller) {
    print('createddddddddddd');
    _controller = controller;
    start();
  }

  Future<void> draw() async {
    dpoints = await f.query();
    print('done');
    print(dpoints);


    polyline.add(Polyline(
        polylineId: PolylineId('$i'),
        points: dpoints,
        visible: true,
        color: Colors.deepPurple,
        width: 1));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('CARP Background Location'),
          ),
          body: Stack(children: <Widget>[
            GoogleMap(
              onMapCreated: _onMapCreated,
              polylines: polyline,
              initialCameraPosition: const CameraPosition(
                target: _center,
                zoom: 11.0,
              ),
            ),
            Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                    alignment: Alignment.topRight,
                    child: FloatingActionButton(
                        onPressed: draw,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        backgroundColor: Colors.purple,
                        child: Text("Draw")))),
          ])),
    );
  }
}
