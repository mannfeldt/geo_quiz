import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geo_quiz/api/overpass_api.dart';
import 'package:geo_quiz/services/geo_service.dart';
import 'package:geo_quiz/services/search_type_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

class Quiz extends StatefulWidget {
  @override
  _QuizState createState() => _QuizState();
}

class _QuizState extends State<Quiz> {
  final MapController _mapController = new MapController();
  final OverpassApi _overpassApi = new OverpassApi();
  GeoService _geoService;

  List<SearchType> _searchTypes = [];
  List<Location> _locations = [];

  Location _currentLocation;
  List<Location> _entities = [];
  SearchType _currentType;
  int _currentRadiusKm = 5;
  bool _answered = false;

  @override
  void initState() {
    _geoService = new GeoService(overpassApi: _overpassApi);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      _initialize();
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Center(
            child:
                Text("Guess what! 🤔", style: TextStyle(color: Colors.black))),
      ),
      body: Center(
          child: Stack(
        children: [_getMap(), _getTopContainer()],
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: _proceed,
        child: Icon(Icons.check),
      ),
    );
  }

  void _initialize() async {
    _searchTypes = await SearchTypeService().getSearchTypes();
    _locations = await _geoService.getLocations();

    _getNewRadius();
    _getNewLocation();
    _getNewSearchType();
  }

  void _proceed() async {
    if (_answered == true) {
      _showNewQuestion();
      return;
    }

    _answerQuestion();
  }

  void _showNewQuestion() {
    setState(() {
      _getNewRadius();
      _getNewLocation();
      _getNewSearchType();
      _entities = [];
      _answered = false;
    });
  }

  Future _answerQuestion() async {
    _indicateLoading();

    _entities = await GeoService(overpassApi: _overpassApi).getEntitiesInArea(
      center: _currentLocation,
      type: _currentType,
      radiusInMetres: (_currentRadiusKm * 1000).toDouble(),
    );

    Navigator.of(context).pop();

    setState(() {
      _answered = true;
    });
  }

  void _getNewSearchType() {
    _currentType = _searchTypes[Random().nextInt(_searchTypes.length)];
  }

  void _getNewRadius() {
    _currentRadiusKm = (Random().nextInt(10) + 1);
  }

  void _indicateLoading() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0))),
            content: Container(
                child: Text(
              'Fetching geo data ...',
              textAlign: TextAlign.center,
            )),
          );
        });
  }

  void _getNewLocation() {
    if (_locations.isEmpty) {
      return;
    }

    setState(() {
      _currentLocation = _locations[Random().nextInt(_locations.length)];
    });

    _mapController.move(
        new LatLng(_currentLocation.latitude, _currentLocation.longitude),
        12.5 - (_currentRadiusKm / 3.6));
  }

  FlutterMap _getMap() {
    return FlutterMap(
      mapController: _mapController,
      options: new MapOptions(
        interactive: false,
        center: _currentLocation != null
            ? new LatLng(_currentLocation.latitude, _currentLocation.longitude)
            : null,
        zoom: 11, //olika zoom beroende på currentRadius?
      ),
      layers: [
        new TileLayerOptions(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c']),
        new MarkerLayerOptions(
          markers: _getMarkers(),
        ),
        new MarkerLayerOptions(
          markers: _getAreaMarkers(),
        ),
      ],
    );
  }

  List<Marker> _getMarkers() {
    List<Marker> markers = [];

    for (Location location in _entities) {
      markers.add(new Marker(
        width: 6,
        height: 6,
        point: new LatLng(location.latitude, location.longitude),
        builder: (ctx) => new Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red),
        ),
      ));
    }

    return markers;
  }

  List<Marker> _getAreaMarkers() {
    if (_currentLocation == null) {
      return [];
    }

    return [
      new Marker(
        width:
            250.0, // denna måste räknas om utifrån _currentRadius olika beronde på zoom också antar jag
        //nej ha fast width/height här. men anpassa zoom till currentRadius
        height: 250.0,
        point:
            new LatLng(_currentLocation.latitude, _currentLocation.longitude),
        builder: (ctx) => new Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.1),
            border: Border.all(color: Colors.blueAccent),
          ),
        ),
      )
    ];
  }

  Container _getTopContainer() {
    return Container(
      alignment: Alignment.topCenter,
      child: Container(
          padding: EdgeInsets.all(32),
          height: 160,
          alignment: Alignment.center,
          width: double.infinity,
          color: Colors.white.withOpacity(0.8),
          child: Text(
            _getText(),
            style: TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
          )),
    );
  }

  String _getText() {
    if (_currentLocation == null) {
      return '';
    }

    if (_currentType == null) {
      return '';
    }

    if (_answered == false) {
      return "How many ${_currentType.plural} are there $_currentRadiusKm km around ${_currentLocation.name}?";
    }

    return "${_entities.length.toString()} ${_currentType.plural}\naround ${_currentLocation.name}";
  }
}
