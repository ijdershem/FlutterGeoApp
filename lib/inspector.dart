import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:map_controller/map_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'map.dart' as map;

class InspectorWidget extends StatefulWidget {
  map.Polygon polygon;

  InspectorWidget(map.Polygon polygon){
    this.polygon = polygon;
  }

  @override
  _InspectorWidgetState createState() => _InspectorWidgetState(polygon);
}

class _InspectorWidgetState extends State<InspectorWidget> {
  map.Polygon polygon;

  _InspectorWidgetState(map.Polygon polygon) {
    this.polygon = polygon;
  }

  @override
  void initState() {
    super.initState();
  }

  @override 
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        elevation: 0,
      ),
    );
  }
}