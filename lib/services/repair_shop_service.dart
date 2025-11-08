import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

Future<List<Map<String, dynamic>>> fetchNearbyRepairShops({int radiusMeters = 3000}) async {
  try {

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final lat = pos.latitude;
    final lon = pos.longitude;

    final query = """
      [out:json];
      (
        node["shop"="car_repair"](around:$radiusMeters,$lat,$lon);
        node["craft"="electronics_repair"](around:$radiusMeters,$lat,$lon);
        node["shop"="bicycle"](around:$radiusMeters,$lat,$lon);
        node["service"="repair"](around:$radiusMeters,$lat,$lon);
      );
      out;
    """;

    final url = "https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}";

    // ✅ 4. Fetch and decode response
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception("Failed to fetch repair shops (status ${response.statusCode}).");
    }

    final data = jsonDecode(response.body);
    if (data["elements"] == null) return [];

    final List<Map<String, dynamic>> shops = [];

    for (var e in data["elements"]) {
      final tags = e["tags"] ?? {};

      // Calculate distance
      final distanceKm = (Geolocator.distanceBetween(lat, lon, e["lat"], e["lon"]) / 1000)
          .toStringAsFixed(2);

      shops.add({
        'name': tags["name"] ?? "Unnamed Repair Shop",
        'category': tags["shop"] ??
            tags["craft"] ??
            tags["service"] ??
            "Repair Shop",
        'distance': distanceKm,
        'rating': (3 + (2 * (e["id"] % 10) / 10)).toStringAsFixed(1),
      });
    }


    shops.sort((a, b) => double.parse(a['distance']).compareTo(double.parse(b['distance'])));

    return shops;
  } catch (e) {
    print("⚠️ Error fetching repair shops: $e");
    return [];
  }
}
