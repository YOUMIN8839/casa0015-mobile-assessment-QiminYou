import 'dart:convert'; // 引入JSON转换库
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  LatLng? currentLocation;
  List<dynamic> nearbyPlaces = []; // 保存从云函数返回的地点
  Set<Polyline> _polylines = Set<Polyline>();
  int _polylineIdCounter = 1; // Helper for generating unique polyline IDs


  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  Stream<int> peopleCountStream() {
    return FirebaseFirestore.instance
        .collection('merchants')
        .doc('Tesco')
        .snapshots()
        .map((snapshot) {
      var people = snapshot.data()?['people']; // Access 'people' safely
      if (people is int) {
        return people; // Directly return if already an int
      } else if (people is String) {
        return int.tryParse(people) ?? 0; // Try parsing if it's a string
      } else {
        return 0; // Return 0 if it's neither int nor String
      }
    });
  }





  Future<List<dynamic>> callCloudFunction(String keyword,
      LatLng location) async {
    var url = Uri.parse(
        'https://europe-west2-discountmanager-421014.cloudfunctions.net/get_near_merchant'); // 请替换成你的云函数URL
    var headers = {'Content-Type': 'application/json'};
    var response = await http.post(
      url,
      headers: headers,
      body: json.encode({
        'keyword': keyword,
        'location': '${location.latitude},${location.longitude}',
      }),
    );

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return data['nearby_places'];
    } else {
      // 如果云函数调用失败
      print('Failed to load nearby places: ${response.body}');
      throw Exception('Failed to load nearby places');
    }
  }

  Future<void> searchNearbyPlaces(String merchantName) async {
    if (currentLocation == null) return;

    try {
      var places = await callCloudFunction(merchantName, currentLocation!);
      setState(() {
        nearbyPlaces = places;
      });
    } catch (e) {
      // 错误处理
      print(e);
      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text('Error'),
              content: Text('Failed to fetch places. Please try again later.'),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
      );
    }
  }

  Future<void> showDirections(LatLng destination) async {
    if (currentLocation == null) return;

    final String googleDirectionsUrl = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${currentLocation!.latitude},${currentLocation!.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        'key=AIzaSyAD4yhVRFXS4PHlKcKbfsNSosazBzgnczs'; // Replace with your Google API key

    final response = await http.get(Uri.parse(googleDirectionsUrl));

    if (response.statusCode == 200) {
      final directionsData = json.decode(response.body);
      if (directionsData['status'] == 'OK') {
        final encodedPoly = directionsData['routes'][0]['overview_polyline']['points'];
        final polylineIdVal = 'polyline_id_$_polylineIdCounter';
        _polylineIdCounter++;

        final polyline = Polyline(
          polylineId: PolylineId(polylineIdVal),
          points: _convertToLatLng(_decodePoly(encodedPoly)),
          color: Colors.blue,
          width: 5,
        );

        setState(() {
          _polylines.clear(); // Remove old polylines
          _polylines.add(polyline); // Add the new polyline
        });
      }
    } else {
      throw Exception('Failed to fetch directions');
    }
  }

  List<LatLng> _convertToLatLng(List<dynamic> polyline) {
    List<LatLng> routeCoords = [];
    polyline.forEach((point) {
      routeCoords.add(LatLng(point.latitude, point.longitude));

    });
    return routeCoords;
  }

  List<dynamic> _decodePoly(String encoded) {
    List<dynamic> poly = [];
    int index = 0,
        len = encoded.length;
    int lat = 0,
        lng = 0;

    while (index < len) {
      int b,
          shift = 0,
          result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      LatLng p = new LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }

    return poly;
  }


  void _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled; request that the user enable them.
      await Geolocator.openLocationSettings();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next step is to try again.
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return;
    }

    // When permissions are granted, continue accessing the position.
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return; // Check if the widget is still in the widget tree
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      // Handle exception
      print(e);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;
    mapController = controller;
  }

  Stream<List<String>> getMerchantNames() {
    var userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    var now = DateTime.now();
    return FirebaseFirestore.instance
        .collection('users/$userId/discounts')
        .where('status', isEqualTo: true)
        .where('endTime', isGreaterThan: now)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs
            .map((doc) => doc.data()['merchantName'].toString())
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: currentLocation == null
                ? Center(child: CircularProgressIndicator())
                : GoogleMap(
              onMapCreated: _onMapCreated,
              polylines: _polylines,
              initialCameraPosition: CameraPosition(
                target: currentLocation!,
                zoom: 14.0,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: StreamBuilder<List<String>>(
              stream: getMerchantNames(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("No active discounts found."));
                }

                var merchantNames = snapshot.data!;
                return ListView.builder(
                  itemCount: merchantNames.length,
                  itemBuilder: (context, index) {
                    return Card(
                      elevation: 4.0,
                      child: ListTile(
                        title: Text(merchantNames[index]),
                        trailing: ElevatedButton(
                          child: Text('Search'),
                          onPressed: () => searchNearbyPlaces(merchantNames[index]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: nearbyPlaces.length,
              itemBuilder: (context, index) {
                final place = nearbyPlaces[index];
                return ListTile(
                  title: Text(place['name']),
                  subtitle: Text("${place['location']['lat']}, ${place['location']['lng']}"),
                  trailing: index == 0 ? StreamBuilder<int>(
                    stream: peopleCountStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator();
                      }
                      return Text(snapshot.hasData ? snapshot.data.toString() : "0");
                    },
                  ) : null,
                  onTap: () {
                    LatLng destination = LatLng(
                      place['location']['lat'],
                      place['location']['lng'],
                    );
                    showDirections(destination);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
