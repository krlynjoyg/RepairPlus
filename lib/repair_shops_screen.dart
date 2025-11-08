import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'saved_shops_screen.dart';

class RepairShopsScreen extends StatefulWidget {
  const RepairShopsScreen({super.key});

  @override
  State<RepairShopsScreen> createState() => _RepairShopsScreenState();
}

class _RepairShopsScreenState extends State<RepairShopsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  GoogleMapController? _mapController;
  Position? _currentLocation;
  List<dynamic> _allShops = [];
  List<dynamic> _nearbyShops = [];
  Set<Marker> _markers = {};
  bool _showOpenNow = false;
  double _maxDistanceKm = 5.0;
  bool _isLoading = false;

  final User? _user = FirebaseAuth.instance.currentUser;
  Set<String> _savedShopIds = {};
  StreamSubscription<QuerySnapshot>? _savedShopsListener;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _savedShopsListener?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (_user != null) _listenToSavedShops();
    if (_allShops.isEmpty || _currentLocation == null) {
      await _getCurrentLocation();
    } else {
      _updateMarkers();
    }
  }

  void _listenToSavedShops() {
    _savedShopsListener = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .collection('saved_shops')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _savedShopIds = snapshot.docs.map((e) => e.id).toSet();
      });
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() => _currentLocation = pos);

    await _fetchNearbyRepairShops(pos.latitude, pos.longitude);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchNearbyRepairShops(double lat, double lon) async {
    const radiusMeters = 5000;


    final query = """
    [out:json];
    (
      node["shop"="repair"](around:$radiusMeters,$lat,$lon);
      node["shop"="electronics"](around:$radiusMeters,$lat,$lon);
      node["shop"="mobile_phone"](around:$radiusMeters,$lat,$lon);
      node["shop"="computer"](around:$radiusMeters,$lat,$lon);
      node["shop"="it"](around:$radiusMeters,$lat,$lon);
      node["craft"="electronics_repair"](around:$radiusMeters,$lat,$lon);
      node["craft"="computer_repair"](around:$radiusMeters,$lat,$lon);
      node["service"="electronics_repair"](around:$radiusMeters,$lat,$lon);
      node["service"="mobile_phone_repair"](around:$radiusMeters,$lat,$lon);
      node["service"="computer_repair"](around:$radiusMeters,$lat,$lon);
      // ✅ Additional repair-related categories
      node["shop"="car_repair"](around:$radiusMeters,$lat,$lon);
      node["shop"="bicycle"](around:$radiusMeters,$lat,$lon);
      node["service"="repair"](around:$radiusMeters,$lat,$lon);
    );
    out;
    """;

    final url =
        "https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _allShops = data["elements"];
          _nearbyShops = List.from(_allShops);
        });
        _applyFilters();
      } else {
        debugPrint("Overpass API returned status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching shops: $e");
    }
  }

  void _applyFilters() {
    if (_currentLocation == null) return;

    final filtered = _allShops.where((shop) {
      final lat = shop['lat'];
      final lon = shop['lon'];
      if (lat == null || lon == null) return false;

      final distanceKm = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        lat,
        lon,
      ) / 1000;

      if (distanceKm > _maxDistanceKm) return false;

      if (_showOpenNow) {
        final tags = shop['tags'] ?? {};
        final hours = tags['opening_hours'];
        if (hours == null) return false;

        final h = hours.toString().toLowerCase();
        if (!(h.contains("24/7") || h.contains("mo") || h.contains("su"))) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      _nearbyShops = filtered;
    });

    _updateMarkers();
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    for (final shop in _nearbyShops) {
      final lat = shop['lat'];
      final lon = shop['lon'];
      if (lat == null || lon == null) continue;

      final name = shop['tags']?['name'] ?? 'Unnamed Repair Shop';
      final type = shop['tags']?['shop'] ??
          shop['tags']?['craft'] ??
          shop['tags']?['service'] ??
          'Repair Service';

      markers.add(Marker(
        markerId: MarkerId(shop['id'].toString()),
        position: LatLng(lat, lon),
        infoWindow: InfoWindow(title: name, snippet: type),
      ));
    }

    setState(() => _markers = markers);
  }

  Future<void> _toggleSaveShop(dynamic shop) async {
    if (_user == null) return;
    final id = shop['id'].toString();

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .collection('saved_shops')
        .doc(id);

    if (_savedShopIds.contains(id)) {
      await ref.delete();
    } else {
      final tags = shop['tags'] ?? {};
      await ref.set({
        'name': tags['name'] ?? 'Unnamed Repair Shop',
        'type': tags['shop'] ??
            tags['craft'] ??
            tags['service'] ??
            'Repair Service',
        'lat': shop['lat'],
        'lon': shop['lon'],
        'address': tags['addr:street'] ?? '',
        'saved_at': FieldValue.serverTimestamp(),
      });
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Filter Repair Shops",
                        style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text("Open Now"),
                        value: _showOpenNow,
                        onChanged: (v) =>
                            setModalState(() => _showOpenNow = v),
                      ),
                      const SizedBox(height: 10),
                      Text(
                          "Max Distance: ${_maxDistanceKm.toStringAsFixed(1)} km"),
                      Slider(
                        value: _maxDistanceKm,
                        min: 1,
                        max: 20,
                        divisions: 19,
                        onChanged: (v) =>
                            setModalState(() => _maxDistanceKm = v),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _applyFilters();
                        },
                        child: const Text(
                          "Apply Filters",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildShopCard(dynamic shop) {
    final id = shop['id'].toString();
    final name = shop['tags']?['name'] ?? 'Unnamed Repair Shop';
    final type = shop['tags']?['shop'] ??
        shop['tags']?['craft'] ??
        shop['tags']?['service'] ??
        'Repair Service';
    final address = shop['tags']?['addr:street'] ?? 'No address available';
    final isSaved = _savedShopIds.contains(id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.build, color: Color(0xFF10B981)),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text("$type\n$address"),
        isThreeLine: true,
        trailing: IconButton(
          icon: Icon(
            isSaved ? Icons.star : Icons.star_border,
            color: isSaved ? Colors.amber : Colors.grey,
          ),
          onPressed: () => _toggleSaveShop(shop),
        ),
        onTap: () => _focusOnShop(shop),
      ),
    );
  }

  void _focusOnShop(dynamic shop) {
    final lat = shop['lat'];
    final lon = shop['lon'];

    if (_mapController != null && lat != null && lon != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lon),
            zoom: 17,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final initialLatLng = _currentLocation != null
        ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
        : const LatLng(14.5995, 120.9842);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B981),
        title: const Text("Nearby Repair Shops",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.star, color: Colors.white),
            tooltip: "Saved Shops",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedShopsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _nearbyShops.isEmpty
          ? const Center(
        child: Text(
          "No repair shops found nearby.",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      )
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
            CameraPosition(target: initialLatLng, zoom: 14),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (c) => _mapController = c,
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.2,
            maxChildSize: 0.65,
            builder: (context, scrollController) {
              return SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, -2))
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 45,
                        height: 6,
                        margin: const EdgeInsets.only(top: 10, bottom: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.only(
                            bottom:
                            MediaQuery.of(context).padding.bottom +
                                80,
                            top: 8,
                          ),
                          itemCount: _nearbyShops.length,
                          itemBuilder: (context, i) =>
                              _buildShopCard(_nearbyShops[i]),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
