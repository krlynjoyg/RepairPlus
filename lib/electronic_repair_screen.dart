import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'services/phone_tutorial_service.dart';
import 'services/history_service.dart';

class ElectronicRepairScreen extends StatefulWidget {
  const ElectronicRepairScreen({super.key});

  @override
  State<ElectronicRepairScreen> createState() => _ElectronicRepairScreenState();
}

class _ElectronicRepairScreenState extends State<ElectronicRepairScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tutorials
  List<NormalizedTutorial> _tutorials = [];
  bool _isLoadingTutorials = false;
  final String youtubeApiKey = 'AIzaSyDHPDJWZqdS8px7AWGW7avsSZU4mHRtz_k';

  // Search
  final TextEditingController _searchController = TextEditingController();

  // Saved IDs
  List<String> _savedTutorialIds = [];

  // Shops
  Position? _currentPosition;
  bool _loadingShops = false;
  List<Map<String, dynamic>> _shops = [];
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  Set<String> _savedShopIds = {};

  StreamSubscription<DocumentSnapshot>? _savedListener;
  StreamSubscription<QuerySnapshot>? _savedShopsListener;

  @override
  void initState() {
    super.initState();
    _listenToSavedLists();
    _prefetchPopularTutorials();
    _determinePositionAndFetchShops();
  }

  @override
  void dispose() {
    _savedListener?.cancel();
    _savedShopsListener?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ===================== Firestore: Saved Tutorials & Shops =====================
  void _listenToSavedLists() {
    final user = _auth.currentUser;
    if (user == null) return;

    _savedListener = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data != null && data['savedElectronicTutorials'] != null) {
        setState(() {
          _savedTutorialIds =
          List<String>.from(data['savedElectronicTutorials']);
        });
      }
    });

    _savedShopsListener = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_electronic_shops')
        .snapshots()
        .listen((snap) {
      setState(() {
        _savedShopIds = snap.docs.map((e) => e.id).toSet();
      });
    });
  }

  // ===================== Log Tutorial to History =====================
  Future<void> _logTutorialToHistory(NormalizedTutorial t) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('history').add({
        'userId': user.uid,
        'title': t.title,
        'subtitle': t.subtitle,
        'image': t.image,
        'url': t.url,
        'type': 'tutorial',
        'category': 'Electronic Repair',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging tutorial to history: $e');
    }
  }

  // ===================== Tutorials Section =====================
  Future<void> _prefetchPopularTutorials() async {
    if (_isLoadingTutorials) return;
    setState(() => _isLoadingTutorials = true);
    try {
      final queries = [
        'electronics repair',
        'how to fix a charger',
        'circuit board repair',
        'speaker repair',
        'TV power supply repair'
      ];
      List<NormalizedTutorial> results = [];
      for (var q in queries) {
        final ifix = await fetchIfixitGuides(q, limit: 5);
        results.addAll(ifix);
        final yt = await fetchYoutubeVideos(q, youtubeApiKey, maxResults: 3);
        results.addAll(yt);
      }
      final map = <String, NormalizedTutorial>{};
      for (var r in results) map[r.id] = r;
      setState(() => _tutorials = map.values.toList());
    } catch (e) {
      debugPrint('Error prefetching electronic tutorials: $e');
    } finally {
      setState(() => _isLoadingTutorials = false);
    }
  }

  Future<void> _searchTutorials(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoadingTutorials = true;
      _tutorials = [];
    });
    try {
      final ifix = await fetchIfixitGuides(query, limit: 20);
      final yt = await fetchYoutubeVideos(query, youtubeApiKey, maxResults: 8);
      final combined = <String, NormalizedTutorial>{};
      for (var t in ifix) combined[t.id] = t;
      for (var t in yt) combined[t.id] = t;
      setState(() => _tutorials = combined.values.toList());
    } catch (e) {
      debugPrint('Search error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch tutorials')));
    } finally {
      setState(() => _isLoadingTutorials = false);
    }
  }

  Future<void> _toggleSaveTutorial(NormalizedTutorial tutorial) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Login required')));
      return;
    }

    final userDoc = _firestore.collection('users').doc(user.uid);
    final historyRef = _firestore.collection('history');
    final safeId = tutorial.id;

    if (_savedTutorialIds.contains(safeId)) {
      // ⭐ Unsave the tutorial
      await userDoc.set({
        'savedElectronicTutorials': FieldValue.arrayRemove([safeId])
      }, SetOptions(merge: true));


      final q = await historyRef
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'tutorial')
          .where('title', isEqualTo: tutorial.title)
          .get();

      for (var doc in q.docs) {
        await doc.reference.update({'isStarred': false});
      }
    } else {

      await userDoc.set({
        'savedElectronicTutorials': FieldValue.arrayUnion([safeId])
      }, SetOptions(merge: true));

      // 🔄 Add or update in history as starred
      final q = await historyRef
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'tutorial')
          .where('title', isEqualTo: tutorial.title)
          .get();

      if (q.docs.isEmpty) {
        await historyRef.add({
          'userId': user.uid,
          'title': tutorial.title,
          'subtitle': tutorial.subtitle,
          'image': tutorial.image,
          'url': tutorial.url,
          'type': 'tutorial',
          'category': 'Electronic Repair',
          'isStarred': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await q.docs.first.reference.update({'isStarred': true});
      }
    }


    setState(() {
      if (_savedTutorialIds.contains(safeId)) {
        _savedTutorialIds.remove(safeId);
      } else {
        _savedTutorialIds.add(safeId);
      }
    });
  }


  // ===================== Nearby Shops =====================
  Future<void> _determinePositionAndFetchShops() async {
    setState(() => _loadingShops = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services disabled')));
        setState(() => _loadingShops = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _loadingShops = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = pos);

      await _fetchNearbyElectronicShops(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('Error fetching position/shops: $e');
    } finally {
      setState(() => _loadingShops = false);
    }
  }

  Future<void> _fetchNearbyElectronicShops(double lat, double lon) async {
    const int radius = 5000;
    final query = """
      [out:json];
      (
        node["shop"="electronics"](around:$radius,$lat,$lon);
        node["craft"="electronics_repair"](around:$radius,$lat,$lon);
        node["service"="electronics_repair"](around:$radius,$lat,$lon);
        node["shop"="car_repair"](around:$radius,$lat,$lon);
        node["shop"="bicycle"](around:$radius,$lat,$lon);
        node["service"="repair"](around:$radius,$lat,$lon);
      );
      out center;
    """;
    final url =
        "https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}";

    try {
      final resp = await http.get(Uri.parse(url));
      final parsed = jsonDecode(resp.body);
      final elements = parsed['elements'] as List<dynamic>? ?? [];
      final shops = <Map<String, dynamic>>[];

      for (var e in elements) {
        final tags = (e['tags'] ?? {}) as Map<String, dynamic>;
        final nodeLat = e['lat'] ?? e['center']?['lat'];
        final nodeLon = e['lon'] ?? e['center']?['lon'];
        if (nodeLat == null || nodeLon == null) continue;
        final name = tags['name'] ?? 'Electronics Repair Shop';

        final distanceKm =
            Geolocator.distanceBetween(lat, lon, nodeLat, nodeLon) / 1000.0;
        final rating =
        (3 + ((e['id'] ?? 0) % 20) / 10).clamp(2.5, 5.0).toStringAsFixed(1);
        shops.add({
          'id': e['id'].toString(),
          'name': name,
          'lat': nodeLat,
          'lon': nodeLon,
          'rating': rating,
          'distance_km': distanceKm
        });
      }

      shops.sort((a, b) =>
          (a['distance_km'] as double).compareTo(b['distance_km'] as double));

      setState(() {
        _shops = shops;
        _markers = shops.isEmpty
            ? {}
            : shops
            .map((s) => Marker(
          markerId: MarkerId(s['id']),
          position: LatLng(s['lat'], s['lon']),
          infoWindow:
          InfoWindow(title: s['name'], snippet: '${s['rating']} ★'),
        ))
            .toSet();
      });
    } catch (e) {
      debugPrint('Error fetching electronic shops: $e');
    }
  }

  Future<void> _toggleSaveShop(Map<String, dynamic> shop) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final id = shop['id'].toString();
    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_electronic_shops')
        .doc(id);
    if (_savedShopIds.contains(id)) {
      await ref.delete();
    } else {
      await ref.set({
        'name': shop['name'],
        'lat': shop['lat'],
        'lon': shop['lon'],
        'rating': shop['rating'],
        'saved_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF10B981),
          title: const Text('Electronic Repair & Guides',
              style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.menu_book), text: 'Tutorials'),
              Tab(icon: Icon(Icons.store), text: 'Nearby Shops'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTutorialsTab(),
            _buildShopsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _searchTutorials(v),
            decoration: InputDecoration(
              hintText: 'Search tutorials (TV, speaker, circuit, etc.)',
              filled: true,
              fillColor: Colors.grey[100],
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _prefetchPopularTutorials();
                },
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingTutorials
              ? const Center(child: CircularProgressIndicator())
              : _tutorials.isEmpty
              ? const Center(child: Text('No tutorials found.'))
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: _tutorials.length,
            itemBuilder: (context, i) {
              final t = _tutorials[i];
              final saved = _savedTutorialIds.contains(t.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      t.image,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey[200]),
                    ),
                  ),
                  title: Text(t.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    t.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                        saved
                            ? Icons.star
                            : Icons.star_border_outlined,
                        color: Colors.amber),
                    onPressed: () => _toggleSaveTutorial(t),
                  ),
                  onTap: () async {
                    final uri = Uri.parse(t.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);


                      await _logTutorialToHistory(t);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShopsTab() {
    return _loadingShops
        ? const Center(child: CircularProgressIndicator())
        : _currentPosition == null
        ? const Center(
        child: Text('Enable location to find nearby shops'))
        : _shops.isEmpty
        ? const Center(child: Text('No repair shops found nearby.'))
        : Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(_currentPosition!.latitude,
                _currentPosition!.longitude),
            zoom: 14,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          markers: _markers,
          onMapCreated: (c) => _mapController = c,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(),
            ),
          },
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.25,
          maxChildSize: 0.65,
          minChildSize: 0.20,
          builder: (context, sc) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 8)
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin:
                    const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.only(
                          top: 0, bottom: 80),
                      itemCount: _shops.length,
                      itemBuilder: (context, i) {
                        final s = _shops[i];
                        final saved = _savedShopIds
                            .contains(s['id'].toString());
                        return ListTile(
                          leading: const Icon(Icons.storefront,
                              color: Color(0xFF10B981)),
                          title: Text(s['name']),
                          subtitle: Text(
                              '${s['distance_km'].toStringAsFixed(2)} km • ${s['rating']} ★'),
                          trailing: IconButton(
                            icon: Icon(
                                saved
                                    ? Icons.star
                                    : Icons.star_border_outlined,
                                color: saved
                                    ? Colors.amber
                                    : Colors.grey),
                            onPressed: () =>
                                _toggleSaveShop(s),
                          ),
                          onTap: () {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                  LatLng(s['lat'], s['lon']), 17),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
