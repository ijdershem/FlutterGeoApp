import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:map_controller/map_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inspector.dart';

//Widget for main flutter_map page
class MapWidget extends StatefulWidget {
  DocumentReference docRef;
  Firestore db;
  FirebaseUser user; 

  MapWidget(Firestore db, DocumentReference docRef, FirebaseUser user) {
    this.db = db;
    this.docRef = docRef;
    this.user = user;
  }

  @override
  _MapWidgetState createState() => _MapWidgetState(this.user, this.db, this.docRef);
}

class _MapWidgetState extends State<MapWidget> {
  MapController mapController;
  StatefulMapController statefulMapController;
  StreamSubscription<StatefulMapControllerStateChange> sub;
  final _formKey = GlobalKey<FormState>();

  bool isDrawingPolygon = false;
  int markerCount = 0;
  bool ready = false; 
  bool editActive = false;
  Color buttonColor = Colors.red;
  IconData editIcon = Icons.add;
  List<LatLng> vertices = []; 

  Firestore db;
  UserMapData userData;
  Future<Map<String, dynamic>> data;

  //TODO: Determine if it would be smarter to use the state of ancestor method: 
  // e.g. UserMapData data = this.context.findAncestorStateOfType<_MapDisplayWidgetState>().userData;
  // for accessing variables that should be accessible more globally than the MapWidget
  _MapWidgetState(FirebaseUser user, Firestore db, DocumentReference docRef) {
    this.userData = new UserMapData(user, docRef);
    this.db = db;
    this.editActive = false; 
    this.data = this.userData.retrieveUserFirestoreData(); //Data for populating drawer of active layers
  }

  @override
  void initState() {
    mapController = MapController();
    statefulMapController = StatefulMapController(mapController: mapController);
    statefulMapController.onReady.then((_) => setState(() => ready = true));

    /// [Important] listen to the changefeed to rebuild the map on changes:
    /// this will rebuild the map when for example addMarker or any method 
    /// that mutates the map assets is called
    sub = statefulMapController.changeFeed.listen((change) => setState(() {}));
    super.initState();
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      drawer: Drawer(   
        child: FutureBuilder<Map<String,dynamic>>(
          future: this.data,
          builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {  
            if(snapshot.hasData) {
              // children = userData.constructDrawerPolygonList(context, snapshot.data);
              print(snapshot.data);
              return polygonListView(context, this.userData, this.statefulMapController);
            } else {
              return Container();
            }
          },        
        ),
      ),
      body: Container(
        child: Stack(
          children: <Widget>[
            FlutterMap(
              mapController: mapController,
              options: new MapOptions(
                center: new LatLng(45.31, -116.35),
                zoom: 10.0,
                onTap: (point) {
                  if(isDrawingPolygon) createPolygonDraft(point, context);
                }, 
                interactive: true,
              ),
              layers: [
                new TileLayerOptions(
                  urlTemplate: "https://api.mapbox.com/styles/v1/ijdersh/ckbe4nvng0t3m1iru312ovavj/"
                  "tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}",
                  additionalOptions: {
                    'accessToken': 'pk.eyJ1IjoiaWpkZXJzaCIsImEiOiJja2JkeHV2amowZzlrMm9ud2diOGcweGplIn0.yKaG_kfWm-4TLSwms608mA',
                  },
                ),
                MarkerLayerOptions(markers: statefulMapController.markers),
                PolylineLayerOptions(polylines: statefulMapController.lines),
                PolygonLayerOptions(polygons: statefulMapController.polygons)
              ],
            ),
            Visibility(
              visible: editActive,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 100, 8),
                  child: ClipOval(
                    child: Material(
                      color: Colors.blue, // button color
                      child: InkWell(
                        splashColor: Colors.white, // inkwell color
                        child: SizedBox(width: 50, height: 50, child: Icon(Icons.undo, size: 30.0, color: Colors.white)),
                        onTap: () {
                          clearMarker(statefulMapController, mostRecent: true);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: editActive,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 8, 100),
                  child: ClipOval(
                    child: Material(
                      color: Colors.redAccent[700], // button color
                      child: InkWell(
                        splashColor: Colors.white, // inkwell color
                        child: SizedBox(width: 50, height: 50, child: Icon(Icons.clear, size: 30.0, color: Colors.white)),
                        onTap: () { // TODO: Make sure user wants to clear draft 
                          clearPolygonDraft(statefulMapController);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 8, 8),
                child: ClipOval(
                  child: Material(
                    color: buttonColor, // button color
                    child: InkWell(
                      splashColor: Colors.white, // inkwell color
                      child: SizedBox(width: 90, height: 90, child: Icon(editIcon, size: 50.0, color: Colors.white)),
                      onTap: () {
                        if(isDrawingPolygon) {
                          this.setState(() {
                            buttonColor = Colors.red;
                            editIcon = Icons.add;
                            editActive = false;
                            if (vertices.length > 2) {
                              createLine(closeLoop: true);
                              showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  content: Stack(
                                    overflow: Overflow.visible,
                                    children: <Widget>[
                                      Form(
                                        key: _formKey,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Padding(
                                              padding: EdgeInsets.fromLTRB(8.0, 2.0, 2.0, 8.0),
                                              child: Text(
                                                  'Name your region',
                                                  textAlign: TextAlign.center,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: TextFormField(
                                                validator: (name) {
                                                  if (name.isEmpty) {
                                                    return 'Please enter a name for your poylgon';
                                                  } else {
                                                    Polygon newPolygon = new Polygon(name, vertices);
                                                    newPolygon.setDisplay(statefulMapController);
                                                    this.userData.addPolygon(newPolygon);
                                                    // statefulMapController.addPolygon(name: name, points: vertices, borderWidth: 2.0, borderColor: Colors.white, color: Colors.white54);
                                                    clearPolygonDraft(statefulMapController);
                                                    return null;
                                                  }
                                                },
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: <Widget>[
                                                Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: RaisedButton(
                                                    child: Text("Save", style: TextStyle(fontSize: 15)),
                                                    onPressed: () {
                                                      if (_formKey.currentState.validate()) {
                                                        _formKey.currentState.save();
                                                        //Remove vertices and lines of polygon draft from map
                                                        clearPolygonDraft(statefulMapController);
                                                      }
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: RaisedButton(
                                                    child: Text("Cancel", style: TextStyle(fontSize: 15)),
                                                    onPressed: () {
                                                      clearLine(statefulMapController, removeClosingLine: true);                                 
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                )
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              });
                            }      
                          });
                        } else {
                          this.setState(() {
                            buttonColor = Colors.green;
                            editIcon = Icons.check;
                            editActive = true;
                          });
                        }
                        isDrawingPolygon = !isDrawingPolygon; 
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  createPolygonDraft(LatLng point, BuildContext context) {
    if(isDrawingPolygon) {
      markerCount += 1;
      print("Adding marker " + markerCount.toString());
      var name = markerCount.toString();
      var marker = Marker(
        point: point, 
        builder: (BuildContext context) {
          return const Icon(Icons.lens, color: Colors.white, size: 16.0);
        });
      statefulMapController.addMarker(marker: marker, name: name);
      vertices.add(point);
    }
    createLine(closeLoop: false);
  }

  // Takes a boolean that indicates if this is the last line for the polygon draft 
  // TODO: should probably adjust this function to take a list of coordinates so that it can be used to create a line at any point
  createLine({bool closeLoop, List<LatLng> points}) {
    if(closeLoop) {
      var points = [vertices[markerCount - 1], vertices[0]];
      var name = (1).toString() + "," + (markerCount).toString();
      print('Line added with name: ' + name);
      statefulMapController.addLine(name: name, points: points, color: Colors.white, width: 3.0);
    } else if (markerCount > 1) {
      for(var i = markerCount-1; i < vertices.length; i++) {
        var points = [vertices[i], vertices[i-1]];
        var name = (i).toString() + "," + (i+1).toString();
        print('Line added with name: ' + name);
        statefulMapController.addLine(name: name, points: points, color: Colors.white, width: 3.0);
      }
    } else {
      print('More than one marker needs to be added to create a line');
    }
  }

  clearLine(StatefulMapController statefulMapController, {bool mostRecent, bool removeClosingLine, List<LatLng> points}) {
    if(removeClosingLine == true) {
      var name = (1).toString() + "," + (markerCount).toString();
      print('Removing line with name: ' + name);
      statefulMapController.removeLine(name);
    } else if(mostRecent == true) {
      var name = (markerCount - 1).toString() + "," + (markerCount).toString();
      print('Removing line with name: ' + name);
      statefulMapController.removeLine(name);
      vertices.removeLast();
    }
  }

  clearMarker(StatefulMapController statefulMapController, {bool mostRecent, List<LatLng> points}) {
    if(mostRecent == true) {
      var name = markerCount.toString();
      print('Removing line with name: ' + name);
      statefulMapController.removeMarker(name: name);
      clearLine(statefulMapController, mostRecent: true);
      markerCount --;
    }
  }

  clearPolygonDraft(StatefulMapController statefulMapController) {
    for(var i = 1; i < markerCount; i++) {
      var lineName = i.toString() + ',' + (i+1).toString();
      var markerName = i.toString(); 
      print('Marker removed with name: ' + lineName);
      statefulMapController.removeLine(lineName);
      statefulMapController.removeMarker(name: markerName);
      if(i+1 == markerCount) {
        statefulMapController.removeMarker(name: (i+1).toString());
        clearLine(statefulMapController, removeClosingLine: true);
      } 
    }
    this.markerCount = 0;
    this.vertices = [];
  }
}

class UserMapData {
  List<Polygon> polygons;
  FirebaseUser user;
  DocumentReference userData;
  Map<String, dynamic> data; 

  UserMapData(FirebaseUser user, DocumentReference userData) {
    this.user = user;
    this.userData = userData; 
    this.polygons = new List<Polygon>();
  }

  addPolygon(Polygon polygon) {
    this.polygons.add(polygon);
    var polygon_data =  {
      'name': polygon.getName(),
      'vertices': polygon.getVertices()
    };
    print(polygon_data);
    this.writeToFirestore('polygon', polygon_data); //TODO: add functionality to write polygon to firestore. Need to create way to name polygons next 
  }

  getPolygons(){
    return this.polygons; 
  }

  // types: polygon, 
  writeToFirestore(String type, Map data) async {
    // Convert lat lng vertices to pairs so they can be written to a dataframe 
    var geoPoints = [];
    List<LatLng> latlng = data['vertices'];
    for(LatLng vertice in latlng) {
      GeoPoint point = new GeoPoint(vertice.latitude, vertice.longitude);
      geoPoints.add(point);
    }

    if(type == "polygon") { //need to make sure the user does not already have a polygon with this name ?
      userData.setData({
        'polygons': {
          data['name']: {
            'points': geoPoints,
          }
        }
      }, merge: true);
    }  
  }

  //TODO:
  // implement function that takes a data type to retrieve the users firestore data and populate the users polygon list upon loading into map 
  // - find a way to persist data even if the user returns to the previous page 
  Future<Map<String, dynamic>> retrieveUserFirestoreData() async {
    DocumentSnapshot userDoc = await userData.get();
    Map<String, dynamic> data = userDoc.data;
    print('In retrieveUserFirestoreData:');
    print(data);

    if(data['polygons'] != null) { //Update user's polygon list
      this.polygons = new List<Polygon>();
      data['polygons'].forEach((k,v) {
        List<dynamic> geoPoints = v['points'];
        List<LatLng> points = geoPointsToLatLng(geoPoints);
        String name = k;
        this.polygons.add(new Polygon(name, points));
      });
    }

    return data;
  }

  List<LatLng> geoPointsToLatLng(List<dynamic> geoPoints) {
    List<LatLng> latLngPoints = [];
    for(GeoPoint vertice in geoPoints) {
      LatLng point = new LatLng(vertice.latitude, vertice.longitude);
      latLngPoints.add(point);
    }
    return latLngPoints;
  }

  removeFromFirestore(String type, String name) {
    //implement
  }
}

class Polygon {
  String name;
  List<LatLng> vertices; 
  bool display = false;

  Polygon(String name, List<LatLng> vertices) {
    this.name = name; 
    this.vertices = vertices;;
  }

  setDisplay(StatefulMapController statefulMapController) {
    this.display = !this.display;
    if(this.display){
      statefulMapController.addPolygon(name: this.name, points: this.vertices, borderWidth: 2.0, borderColor: Colors.white, color: Colors.white54);
    } else {
      statefulMapController.removePolygon(this.name);
    }
  }

  set displayPolygon(bool visible) => this.display = visible;

  getName() {
    return this.name;
  }

  getVertices() {
    return this.vertices;
  }

  updateVertices(List<LatLng> vertices){
    this.vertices = vertices; 
  }
}

Widget polygonListView(BuildContext context, UserMapData data, StatefulMapController statefulMapController) {
  List<Polygon> polygons = data.polygons;
  List<Widget> polygonList = [
    Material(
      color: Colors.red,
      child: SizedBox(
        child: Text('Active Layers', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        height: 50,
        width: 100,
      ),
    )
  ];

  for(Polygon polygon in polygons) {
    PolygonListTile listTile = new PolygonListTile(context, polygon, statefulMapController);
    if(!polygonList.contains(listTile)) {
      polygonList.add(listTile);
    }
  }

  return ListView(
          children: polygonList,
          padding: EdgeInsets.zero,
        );

}

class PolygonListTile extends StatefulWidget{
  BuildContext context;
  Polygon polygon;
  StatefulMapController statefulMapController;

  PolygonListTile(BuildContext context, Polygon polygon, StatefulMapController statefulMapController) {
    this.context = context;
    this.polygon = polygon; 
    this.statefulMapController = statefulMapController;
  }

  @override
  _PolygonListTileState createState() => _PolygonListTileState(context, polygon, statefulMapController);
}

class _PolygonListTileState extends State<PolygonListTile> {
  BuildContext context;
  Polygon polygon;
  bool _active = true;
  StatefulMapController statefulMapController;

  _PolygonListTileState(BuildContext context, Polygon polygon, StatefulMapController statefulMapController) {
    this.context = context;
    this.polygon = polygon;
    this.statefulMapController = statefulMapController;
    this._active = polygon.display; //Check if a polygon is active on the map to set its switch property
  }

  void _handleToggle(bool value) {
    setState(() {
      _active = value;
      polygon.setDisplay(statefulMapController);
    });
  }

  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Row(
        children: <Widget>[
          Flexible(
            child: ListTile(
              title: Text(polygon.name),
              onTap: () => {    
                Navigator.push(context,
                  MaterialPageRoute(builder: (BuildContext context) => InspectorWidget(polygon)))
              },
            ),
          ),
          Switch(
            value: _active, 
            onChanged: (value) => _handleToggle(value),
          ),
        ],
      ),
    );
  }
}


