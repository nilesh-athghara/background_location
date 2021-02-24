import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:poc_location/toast.dart';
import 'package:poc_location/validations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager.initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  runApp(MyApp());
}

void callbackDispatcher() {
  Workmanager.executeTask((task, inputData) async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    await http.post(inputData["api"], body: {
      "device": inputData["device"],
      "appState": "killed",
      "lat": position.latitude.toString(),
      "lng": position.longitude.toString()
    });
    return Future.value(true);
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poc_location',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: MyHomePage(title: 'Location demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({Key key, this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController uniqueId = TextEditingController();
  TextEditingController apiController = TextEditingController();
  bool started = false;
  final formKey = GlobalKey<FormState>();
  Timer t;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    if (t != null) {
      t.cancel();
    }
    super.dispose();
  }

  void init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String api = prefs.getString("api");
    String device = prefs.getString("device");
    if (api != null && device != null) {
      setState(() {
        apiController.text = api;
        uniqueId.text = device;
        started = true;
      });
      if (t == null) {
        Timer.periodic(Duration(minutes: 5), (timer) async {
          Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
          http.post(apiController.text, body: {
            "device": uniqueId.text,
            "appState": "running",
            "lat": position.latitude.toString(),
            "lng": position.longitude.toString()
          });
        });
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Container(
          margin: EdgeInsets.all(20),
          child: Column(
            children: [
              RaisedButton(
                onPressed: () async {
                  PermissionStatus permission;
                  bool serviceEnabled =
                      await Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled) {
                    showToast("Please enable location service.");
                  } else {
                    permission = await Permission.locationAlways.status;
                    if (permission == PermissionStatus.permanentlyDenied) {
                      showToast(
                          'Location permissions are permantly denied, cannot request permissions.');
                    } else if (permission != PermissionStatus.granted) {
                      permission = await Permission.locationAlways.request();
                    }
                  }
                },
                child: Text("Give Permissions"),
              ),
              Text(
                  "Please provide \"Allow all the time\" permission to continue further."),
              SizedBox(
                height: 40.0,
              ),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: uniqueId,
                      enabled: !started,
                      validator: (val) {
                        return nullTextValidate(val);
                      },
                      decoration: InputDecoration(
                          hintText: "Enter device name (For logs)"),
                    ),
                    SizedBox(
                      height: 20.0,
                    ),
                    TextFormField(
                      controller: apiController,
                      enabled: !started,
                      validator: (val) {
                        return nullTextValidate(val);
                      },
                      decoration: InputDecoration(hintText: "Enter api url"),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 20.0,
              ),
              started
                  ? Container()
                  : RaisedButton(
                      onPressed: () async {
                        PermissionStatus permission =
                            await Permission.locationAlways.status;
                        if (permission == PermissionStatus.granted) {
                          if (formKey.currentState.validate()) {
                            await Workmanager.cancelAll();
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            prefs.setString("device", uniqueId.text);
                            prefs.setString("api", apiController.text);
                            Workmanager.registerPeriodicTask(
                                "2", "simplePeriodicTask",
                                frequency: Duration(minutes: 15),
                                inputData: {
                                  "api": apiController.text,
                                  "device": uniqueId.text
                                });
                            t = Timer.periodic(Duration(minutes: 5),
                                (timer) async {
                              Position position =
                                  await Geolocator.getCurrentPosition(
                                      desiredAccuracy: LocationAccuracy.high);
                              http.post(apiController.text, body: {
                                "device": uniqueId.text,
                                "appState": "running",
                                "lat": position.latitude.toString(),
                                "lng": position.longitude.toString()
                              });
                            });
                            setState(() {
                              started = true;
                            });
                          }
                        } else {
                          showToast(
                              "Please provide required permission to continue.");
                        }
                      },
                      child: Text("Get location updates"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
