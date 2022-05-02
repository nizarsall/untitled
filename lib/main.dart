import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carp_background_location/carp_background_location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_map_polyline/google_map_polyline.dart';
import 'database/funcs.dart';

final f = funcs.instance;
void main() => runApp(MyApp());

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
    return Column(
      children: <Widget>[
        Text(
          '${dto.latitude}, ${dto.longitude}',
        ),
        Text(
          '@',
        ),
        Text('${DateTime.fromMillisecondsSinceEpoch(dto.time ~/ 1)}')
      ],
    );
  }
}

class _MyAppState extends State<MyApp> {
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
    f.query();
    
    LocationManager().interval = 1;
    LocationManager().distanceFilter = 0;
    LocationManager().notificationTitle = 'CARP Location Example';
    LocationManager().notificationMsg = 'CARP is tracking your location';
    locationStream = LocationManager().locationStream;
    start();
    _status = LocationStatus.INITIALIZED;
  }

  void getCurrentLocation() async =>
      onData(await LocationManager().getCurrentLocation());

  void onData(LocationDto dto) {
    print(dtoToString(dto));
    LatLng p = new LatLng(dto.latitude, dto.longitude);
    if (p != null) {
      points.add(p);
    }

    i++;
    print("inside");
    print(dto);
    f.insert(dto.latitude, dto.longitude);
    _controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(dto.latitude, dto.longitude),
      zoom: 18.0,
    )));
    //print(points);
    setState(() {
      lastLocation = dto;
      lastTimeLocation = DateTime.now();
      if (i > 1) {
        polyline.add(Polyline(
            polylineId: PolylineId('${i}'),
            points: points,
            visible: true,
            color: Colors.red,
            width: 4));
      }
    });
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

  static const LatLng _center = const LatLng(36.2798501, 36.2772437);

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
          color: Colors.red,
          width: 20));
   
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
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 11.0,
              ),
            ),
            FloatingActionButton(
                onPressed: getCurrentLocation, child: Text("start")),
            Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                    alignment: Alignment.topRight,
                    child: FloatingActionButton(
                      onPressed: draw,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.map, size: 36.0),
                    ))),
          ])),
    );
  }
}
